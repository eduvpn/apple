//
//  ConnectionService.swift
//  EduVPN
//

import Foundation
import NetworkExtension
import PromiseKit
import TunnelKit
import os.log

protocol ConnectionServiceInitializationDelegate: class {
    func connectionService(
        _ service: ConnectionServiceProtocol,
        initializedWithState: ConnectionServiceInitializedState)
}

protocol ConnectionServiceStatusDelegate: class {
    func connectionService(_ service: ConnectionServiceProtocol, connectionStatusChanged status: NEVPNStatus)
}

enum ConnectionServiceError: Error {
    case cannotStartTunnel
    case cannotStopTunnel
    case cannotSendMessageWhenNotConnected
    case receivedEmptyMessageResponse
}

extension ConnectionServiceError: AppError {
    var summary: String {
        switch self {
        case .cannotStartTunnel:
            return "Cannot start the tunnel"
        case .cannotStopTunnel:
            return "Cannot stop the tunnel"
        case .cannotSendMessageWhenNotConnected:
            return "Cannot send message when not connected"
        case .receivedEmptyMessageResponse:
            return "Received empty message response"
        }
    }
}

enum ConnectionServiceInitializedState {
    case vpnEnabled(connectionAttemptId: UUID?)
    case vpnDisabled
}

struct NetworkAddress {
    let ipv4: String?
    let ipv6: String?
}

struct TransferredByteCount {
    let inbound: UInt64
    let outbound: UInt64
}

struct Credentials {
    let userName: String
    let password: String
}

protocol ConnectionServiceProtocol: class {

    var initializationDelegate: ConnectionServiceInitializationDelegate? { get set }
    var statusDelegate: ConnectionServiceStatusDelegate? { get set }

    var isInitialized: Bool { get }
    var connectionStatus: NEVPNStatus { get }
    var isVPNEnabled: Bool { get }
    var connectionAttemptId: UUID? { get }
    var connectedDate: Date? { get }

    func enableVPN(openVPNConfig: [String], connectionAttemptId: UUID,
                   credentials: Credentials?,
                   shouldDisableVPNOnError: Bool,
                   shouldPreventAutomaticConnections: Bool) -> Promise<Void>
    func enableVPN(wireGuardConfig: String, serverName: String, connectionAttemptId: UUID,
                   shouldDisableVPNOnError: Bool) -> Promise<Void>
    func disableVPN() -> Promise<Void>

    func getNetworkAddress() -> Guarantee<NetworkAddress>
    func getTransferredByteCount() -> Guarantee<TransferredByteCount>
    func getConnectionLog() -> Promise<String?>
}

class ConnectionService: ConnectionServiceProtocol {

    weak var initializationDelegate: ConnectionServiceInitializationDelegate?
    weak var statusDelegate: ConnectionServiceStatusDelegate?

    private var tunnelManager: NETunnelProviderManager?

    var isInitialized: Bool { tunnelManager != nil }
    var connectionStatus: NEVPNStatus { tunnelManager?.connection.status ?? .invalid }
    var isVPNEnabled: Bool { tunnelManager?.isOnDemandEnabled ?? false }
    var connectionAttemptId: UUID? { tunnelManager?.connectionAttemptId }
    var connectedDate: Date? { tunnelManager?.session.connectedDate }

    private var statusObservationToken: AnyObject?
    private var startTunnelPromiseResolver: Resolver<Void>?
    private var stopTunnelPromiseResolver: Resolver<Void>?
    private var viewLogPromiseResolver: Resolver<Void>?

    init() {
        initializeTunnelManager()
        startObservingTunnelStatus()
    }

    private func initializeTunnelManager() {
        firstly {
            NETunnelProviderManager.loadAllFromPreferences()
        }.map { savedTunnelManagers in
            let tunnelManager = savedTunnelManagers.first ?? NETunnelProviderManager()
            self.tunnelManager = tunnelManager
            let initializedState: ConnectionServiceInitializedState
            if tunnelManager.isOnDemandEnabled {
                initializedState = .vpnEnabled(connectionAttemptId: tunnelManager.connectionAttemptId)
            } else {
                initializedState = .vpnDisabled
            }
            self.initializationDelegate?.connectionService(self, initializedWithState: initializedState)
            let status = tunnelManager.connection.status
            logConnectionStatus(status)
            self.statusDelegate?.connectionService(self, connectionStatusChanged: status)
        }.recover { error in
            os_log("Error loading tunnels: %{public}@", log: Log.general, type: .error,
                   error.localizedDescription)
        }
    }

    func enableVPN(openVPNConfig: [String], connectionAttemptId: UUID,
                   credentials: Credentials?,
                   shouldDisableVPNOnError: Bool,
                   shouldPreventAutomaticConnections: Bool) -> Promise<Void> {
        #if os(iOS)
        precondition(shouldPreventAutomaticConnections == false)
        #endif

        return firstly { () -> Promise<NETunnelProviderProtocol> in
            let protocolConfig = try Self.tunnelProtocolConfiguration(
                openVPNConfig: openVPNConfig,
                connectionAttemptId: connectionAttemptId,
                credentials: credentials,
                shouldPreventAutomaticConnections: shouldPreventAutomaticConnections)
            return Promise.value(protocolConfig)
        }.then { protocolConfig -> Promise<Void> in
            self.enableVPN(
                protocolConfig: protocolConfig,
                shouldDisableVPNOnError: shouldDisableVPNOnError)
        }
    }

    func enableVPN(wireGuardConfig: String, serverName: String, connectionAttemptId: UUID,
                   shouldDisableVPNOnError: Bool) -> Promise<Void> {
        let protocolConfig = Self.tunnelProtocolConfiguration(
            wireGuardConfig: wireGuardConfig,
            serverName: serverName,
            connectionAttemptId: connectionAttemptId)
        return self.enableVPN(
            protocolConfig: protocolConfig,
            shouldDisableVPNOnError: shouldDisableVPNOnError)
    }

    private func enableVPN(protocolConfig: NETunnelProviderProtocol, shouldDisableVPNOnError: Bool) -> Promise<Void> {
        guard let tunnelManager = tunnelManager else {
            fatalError("ConnectionService not initialized yet")
        }
        tunnelManager.protocolConfiguration = protocolConfig
        tunnelManager.isEnabled = true
        tunnelManager.isOnDemandEnabled = true
        tunnelManager.onDemandRules = [NEOnDemandRuleConnect()]
        return firstly {
            tunnelManager.saveToPreferences()
        }.then { _ -> Promise<Void> in
            // Load back the saved preferences to avoid NEVPNErrorConfigurationInvalid error
            // See: https://developer.apple.com/forums/thread/25928
            tunnelManager.loadFromPreferences()
        }.then { _ -> Promise<Void> in
            switch tunnelManager.connection.status {
            case .connected, .connecting, .reasserting:
                return firstly {
                    self.stopTunnel()
                }.then { _ in
                    self.startTunnel()
                }
            default:
                return self.startTunnel()
            }
        }.recover { error in
            if shouldDisableVPNOnError {
                // If there was an error starting the tunnel, disable on-demand
                firstly { () -> Promise<Void> in
                    if tunnelManager.isOnDemandEnabled {
                        return self.disableVPN()
                    } else {
                        return Promise.value(())
                    }
                }.catch { disablingError in
                    os_log("Error disabling VPN \"%{public}@\" while recovering from error enabling VPN \"%{public}@\"",
                           log: Log.general, type: .error, disablingError.localizedDescription, error.localizedDescription)
                }
            }
            throw error
        }
    }

    func disableVPN() -> Promise<Void> {
        guard let tunnelManager = tunnelManager else {
            fatalError("ConnectionService not initialized yet")
        }
        return firstly { () -> Promise<Void> in
            tunnelManager.isEnabled = false
            tunnelManager.isOnDemandEnabled = false
            tunnelManager.onDemandRules = []
            return tunnelManager.saveToPreferences()
        }.then { _ -> Promise<Void> in
            switch tunnelManager.connection.status {
            case .connected, .connecting, .reasserting:
                return self.stopTunnel()
            default:
                return Promise.value(())
            }
        }
    }
}

extension ConnectionService {
    func getNetworkAddress() -> Guarantee<NetworkAddress> {
        guard let tunnelManager = tunnelManager else {
            fatalError("ConnectionService not initialized yet")
        }
        return firstly {
            tunnelManager.sendProviderMessage(
                OpenVPNTunnelProvider.Message.serverConfiguration.data)
        }.map { data in
            guard let config = try? JSONDecoder().decode(OpenVPN.Configuration.self, from: data) else {
                return NetworkAddress(ipv4: nil, ipv6: nil)
            }
            return NetworkAddress(
                ipv4: config.ipv4?.address,
                ipv6: config.ipv6?.address)
        }.recover { error in
            os_log("Error getting server configuration from tunnel: %{public}@",
                   log: Log.general, type: .error, error.localizedDescription)
            return Guarantee.value(NetworkAddress(ipv4: nil, ipv6: nil))
        }
    }

    func getTransferredByteCount() -> Guarantee<TransferredByteCount> {
        guard let tunnelManager = tunnelManager else {
            fatalError("ConnectionService not initialized yet")
        }
        return firstly {
            tunnelManager.sendProviderMessage(
                OpenVPNTunnelProvider.Message.dataCount.data)
        }.map { data in
            return data.withUnsafeBytes { pointer -> TransferredByteCount in
                // Data is 16 bytes: low 8 = received, high 8 = sent.
                let inbound = pointer.load(fromByteOffset: 0, as: UInt64.self)
                let outbound = pointer.load(fromByteOffset: 8, as: UInt64.self)
                return TransferredByteCount(inbound: inbound, outbound: outbound)
            }
        }.recover { error in
            os_log("Error getting data count from tunnel: %{public}@",
                   log: Log.general, type: .error, error.localizedDescription)
            return Guarantee.value(TransferredByteCount(inbound: 0, outbound: 0))
        }
    }
}

extension ConnectionService {
    func getConnectionLog() -> Promise<String?> {
        guard let tunnelManager = tunnelManager else {
            fatalError("ConnectionService not initialized yet")
        }
        guard tunnelManager.connection.status != .disconnecting else {
            // If the tunnel is disconnecting, it might be writing to the log
            // file. So let's wait for it to disconnect, and then read the file.
            return Promise { resolver in
                self.viewLogPromiseResolver = resolver
            }.then { _ in
                return self.getConnectionLog()
            }
        }
        switch tunnelManager.connection.status {
        case .connected, .reasserting:
            // Ask the tunnel process for the log
            return firstly {
                tunnelManager.sendProviderMessage(
                    OpenVPNTunnelProvider.Message.requestLog.data)
            }.map { data in
                return String(data: data, encoding: .utf8)
            }
        default:
            // Read the log file directly
            guard let appGroupURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: ConnectionService.appGroup) else {
                    return Promise.value(nil)
            }
            let debugLogURL = appGroupURL.appendingPathComponent("debug.log")
            let debugLog = try? String(contentsOf: debugLogURL)
            return Promise.value(debugLog)
        }
    }
}

private extension ConnectionService {
    func startTunnel() -> Promise<Void> {
        guard let tunnelManager = tunnelManager else {
            fatalError("ConnectionService not initialized yet")
        }
        return Promise { resolver in
            do {
                #if os(macOS)
                let startTunnelOptions = StartTunnelOptions(isStartedByApp: true)
                try tunnelManager.session.startTunnel(options: startTunnelOptions.options)
                #else
                try tunnelManager.session.startTunnel()
                #endif
            } catch {
                throw error
            }
            self.startTunnelPromiseResolver = resolver
        }
    }

    func stopTunnel() -> Promise<Void> {
        guard let tunnelManager = tunnelManager else {
            fatalError("ConnectionService not initialized yet")
        }
        return Promise { resolver in
            tunnelManager.session.stopTunnel()
            self.stopTunnelPromiseResolver = resolver
        }
    }

    func startObservingTunnelStatus() {
        statusObservationToken = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange, object: nil,
            queue: OperationQueue.main) { [weak self] notification in
                guard let self = self else { return }
                guard let session = notification.object as? NETunnelProviderSession else { return }

                let status = session.status
                logConnectionStatus(status)
                self.statusDelegate?.connectionService(self, connectionStatusChanged: status)

                if status == .connected {
                    self.startTunnelPromiseResolver?.fulfill(())
                    self.stopTunnelPromiseResolver?.reject(ConnectionServiceError.cannotStopTunnel)
                    self.viewLogPromiseResolver?.reject(ConnectionServiceError.cannotStopTunnel)
                }
                if status == .disconnected {
                    self.stopTunnelPromiseResolver?.fulfill(())
                    self.viewLogPromiseResolver?.fulfill(())
                    self.startTunnelPromiseResolver?.reject(ConnectionServiceError.cannotStartTunnel)
                }
                if status == .connected || status == .disconnected {
                    self.startTunnelPromiseResolver = nil
                    self.stopTunnelPromiseResolver = nil
                    self.viewLogPromiseResolver = nil
                }
        }
    }
}

private extension ConnectionService {
    static var appBundleId: String {
        guard let appId = Bundle.main.bundleIdentifier else { fatalError("missing bundle id") }
        return appId
    }

    static var openVPNTunnelBundleId: String {
        return "\(appBundleId).OpenVPNTunnelExtension"
    }

    static var wireGuardTunnelBundleId: String {
        return "\(appBundleId).WireGuardTunnelExtension"
    }

    static var appGroup: String {
        #if os(macOS)
        return "\((Bundle.main.infoDictionary?["AppIdentifierPrefix"] as? String) ?? "")group.\(appBundleId)"
        #elseif os(iOS)
        return "group.\(appBundleId)"
        #endif
    }

    static func tunnelProtocolConfiguration(
        openVPNConfig lines: [String], connectionAttemptId: UUID,
        credentials: Credentials?, shouldPreventAutomaticConnections: Bool) throws
    -> NETunnelProviderProtocol {
        let filteredLines = lines.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter {
            !$0.isEmpty
        }
        let parseResult = try OpenVPN.ConfigurationParser.parsed(fromLines: filteredLines)

        var configBuilder = parseResult.configuration.builder()
        configBuilder.tlsSecurityLevel = 3 // See https://github.com/eduvpn/apple/issues/89

        var providerConfigBuilder = OpenVPNTunnelProvider.ConfigurationBuilder(sessionConfiguration: configBuilder.build())
        providerConfigBuilder.masksPrivateData = false
        providerConfigBuilder.shouldDebug = true

        let providerConfig = providerConfigBuilder.build()

        if let credentials = credentials {
            let keychain = Keychain(group: appGroup)
            try keychain.set(
                password: credentials.password, for: credentials.userName,
                context: openVPNTunnelBundleId)
        }
        let tunnelProviderProtocolConfig = try providerConfig.generatedTunnelProtocol(
            withBundleIdentifier: openVPNTunnelBundleId,
            appGroup: appGroup,
            context: openVPNTunnelBundleId,
            username: credentials?.userName)
        tunnelProviderProtocolConfig.connectionAttemptId = connectionAttemptId
        #if os(macOS)
        tunnelProviderProtocolConfig.shouldPreventAutomaticConnections = shouldPreventAutomaticConnections
        #elseif os(iOS)
        precondition(shouldPreventAutomaticConnections == false)
        #endif

        return tunnelProviderProtocolConfig
    }

    static func tunnelProtocolConfiguration(
        wireGuardConfig: String, serverName: String, connectionAttemptId: UUID) -> NETunnelProviderProtocol {
        let protocolConfiguration = NETunnelProviderProtocol()
        protocolConfiguration.providerBundleIdentifier = wireGuardTunnelBundleId
        protocolConfiguration.serverAddress = serverName
        protocolConfiguration.providerConfiguration = [
            "WireGuardConfig": wireGuardConfig,
            "AppGroup": appGroup
        ]
        protocolConfiguration.connectionAttemptId = connectionAttemptId
        return protocolConfiguration
    }
}

extension NETunnelProviderManager {
    var session: NETunnelProviderSession {
        guard let session = connection as? NETunnelProviderSession else {
            fatalError("Tunnel provider connection is not an NETunnelProviderSession")
        }
        return session
    }

    var connectionAttemptId: UUID? {
        guard let protocolConfig = protocolConfiguration as? NETunnelProviderProtocol else {
            return nil
        }
        return protocolConfig.connectionAttemptId
    }

    class func loadAllFromPreferences() -> Promise<[NETunnelProviderManager]> {
        Promise { seal in
            NETunnelProviderManager.loadAllFromPreferences { (managers, error) in
                seal.resolve(managers ?? [], error)
            }
        }
    }

    func saveToPreferences() -> Promise<Void> {
        Promise { seal in
            saveToPreferences { error in
                seal.resolve((), error)
            }
        }
    }

    func loadFromPreferences() -> Promise<Void> {
        Promise { seal in
            loadFromPreferences { error in
                seal.resolve((), error)
            }
        }
    }

    func sendProviderMessage(_ messageData: Data) -> Promise<Data> {
        guard connection.status == .connected else {
            return Promise(error:
                ConnectionServiceError.cannotSendMessageWhenNotConnected)
        }
        return Promise { seal in
            try session.sendProviderMessage(messageData) { responseData in
                guard let responseData = responseData else {
                    seal.reject(
                        ConnectionServiceError.receivedEmptyMessageResponse)
                    return
                }
                seal.fulfill(responseData)
            }
        }
    }
}

// MARK: - NETunnelProviderProtocol + connectionAttemptId

extension NETunnelProviderProtocol {
    struct Keys {
        static let connectionAttemptId = "ConnectionAttemptID"
    }

    var connectionAttemptId: UUID? {
        get {
            if let uuidString = providerConfiguration?[Keys.connectionAttemptId] as? String {
                return UUID(uuidString: uuidString)
            }
            return nil
        }

        set(value) {
            providerConfiguration?[Keys.connectionAttemptId] = value?.uuidString
        }
    }
}

private func logConnectionStatus(_ status: NEVPNStatus) {
    let statusString: String = {
        switch status {
        case .invalid: return "Invalid"
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting"
        case .connected: return "Connected"
        case .reasserting: return "Reasserting"
        case .disconnecting: return "Disconnecting"
        @unknown default: return "Unknown"
        }
    }()
    os_log("Connection status: %{public}@", log: Log.general, type: .info, statusString)
}
