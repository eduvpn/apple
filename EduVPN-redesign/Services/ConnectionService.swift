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
    func connectionServiceInitialized(
        isVPNEnabled: Bool, configurationSource: ConnectionService.ConfigurationSource?)
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

protocol ConnectionServiceStatusDelegate: class {
    func connectionStatusChanged(status: NEVPNStatus)
}

class ConnectionService {

    enum ConfigurationSource {
        case server(localStoragePath: String)
        // case openVPNConfigFile(fileName: String)
    }

    weak var initializationDelegate: ConnectionServiceInitializationDelegate?
    weak var statusDelegate: ConnectionServiceStatusDelegate?

    private var tunnelManager: NETunnelProviderManager?

    var isInitialized: Bool { tunnelManager != nil }
    var connectionStatus: NEVPNStatus { tunnelManager?.connection.status ?? .invalid }
    var isVPNEnabled: Bool { tunnelManager?.isOnDemandEnabled ?? false }
    var configurationSource: ConfigurationSource? { tunnelManager?.configurationSource }
    var connectedDate: Date? { tunnelManager?.session.connectedDate }

    private var statusObservationToken: AnyObject?
    private var startTunnelPromiseResolver: Resolver<Void>?
    private var stopTunnelPromiseResolver: Resolver<Void>?

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
            self.initializationDelegate?.connectionServiceInitialized(
                isVPNEnabled: tunnelManager.isOnDemandEnabled,
                configurationSource: tunnelManager.configurationSource)
            self.statusDelegate?.connectionStatusChanged(
                status: tunnelManager.connection.status)
        }.recover { error in
            os_log("Error loading tunnels: %{public}@", log: Log.general, type: .error,
                   error.localizedDescription)
        }
    }

    func enableVPN(openVPNConfig: [String], configSource: ConfigurationSource) -> Promise<Void> {
        guard let tunnelManager = tunnelManager else {
            fatalError("ConnectionService not initialized yet")
        }
        return firstly { () -> Promise<NETunnelProviderProtocol> in
            let protocolConfig = try Self.tunnelProtocolConfiguration(
                openVPNConfig: openVPNConfig, configSource: configSource)
            return Promise.value(protocolConfig)
        }.then { protocolConfig -> Promise<Void> in
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
                throw error
            }
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
    struct NetworkAddress {
        let ipv4: String?
        let ipv6: String?
    }

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

    struct TransferredByteCount {
        let inbound: UInt64
        let outbound: UInt64
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

private extension ConnectionService {
    func startTunnel() -> Promise<Void> {
        guard let tunnelManager = tunnelManager else {
            fatalError("ConnectionService not initialized yet")
        }
        return Promise { resolver in
            do {
                try tunnelManager.session.startTunnel()
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
                self.statusDelegate?.connectionStatusChanged(status: status)

                if status == .connected {
                    self.startTunnelPromiseResolver?.fulfill(())
                    self.stopTunnelPromiseResolver?.reject(ConnectionServiceError.cannotStopTunnel)
                }
                if status == .disconnected {
                    self.stopTunnelPromiseResolver?.fulfill(())
                    self.startTunnelPromiseResolver?.reject(ConnectionServiceError.cannotStartTunnel)
                }
                if status == .connected || status == .disconnected {
                    self.startTunnelPromiseResolver = nil
                    self.stopTunnelPromiseResolver = nil
                }
        }
    }
}

private extension ConnectionService {
    static var appBundleId: String {
        guard let appId = Bundle.main.bundleIdentifier else { fatalError("missing bundle id") }
        return appId
    }

    static var providerBundleIdentifier: String {
        return "\(appBundleId).TunnelExtension"
    }

    static var appGroup: String {
        #if os(macOS)
        return "\((Bundle.main.infoDictionary?["AppIdentifierPrefix"] as? String) ?? "")group.\(appBundleId)"
        #elseif os(iOS)
        return "group.\(bundleID)"
        #endif
    }

    static func tunnelProtocolConfiguration(
        openVPNConfig lines: [String], configSource: ConfigurationSource) throws
        -> NETunnelProviderProtocol {
            let parseResult = try OpenVPN.ConfigurationParser.parsed(fromLines: lines)

            var configBuilder = parseResult.configuration.builder()
            configBuilder.tlsSecurityLevel = 3 // See https://github.com/eduvpn/apple/issues/89

            var providerConfigBuilder = OpenVPNTunnelProvider.ConfigurationBuilder(sessionConfiguration: configBuilder.build())
            providerConfigBuilder.masksPrivateData = false
            providerConfigBuilder.shouldDebug = true

            let providerConfig = providerConfigBuilder.build()
            let tunnelProviderProtocolConfig = try providerConfig.generatedTunnelProtocol(
                withBundleIdentifier: providerBundleIdentifier,
                appGroup: appGroup)
            configSource.store(to: &tunnelProviderProtocolConfig.providerConfiguration)

            return tunnelProviderProtocolConfig
    }
}

extension NETunnelProviderManager {
    var session: NETunnelProviderSession {
        guard let session = connection as? NETunnelProviderSession else {
            fatalError("Tunnel provider connection is not an NETunnelProviderSession")
        }
        return session
    }

    var configurationSource: ConnectionService.ConfigurationSource? {
        guard let protocolConfig = protocolConfiguration as? NETunnelProviderProtocol else {
            return nil
        }
        return ConnectionService.ConfigurationSource(from: protocolConfig.providerConfiguration)
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

// MARK: - ConfigurationSource + providerConfiguration

extension ConnectionService.ConfigurationSource {
    struct Keys {
        static let serverLocalStoragePath = "ServerLocalStoragePath"
        static let openVPNConfigFileName = "OpenVPNConfigFileName"
    }

    func store(to dict: inout [String: Any]?) {
        switch self {

        case .server(let localStoragePath):
            dict?[Keys.serverLocalStoragePath] = localStoragePath
        // case .openVPNConfigFile(let fileName):
        //    dict?[Keys.openVPNConfigFileName] = fileName
        }
    }

    init?(from dict: [String: Any]?) {
        if let localStoragePath = dict?[Keys.serverLocalStoragePath] as? String {
            self = .server(localStoragePath: localStoragePath)
        // } else if let fileName = dict?[Keys.openVPNConfigFileName] as? String {
        //     self = .openVPNConfigFile(fileName: fileName)
        }
        return nil
    }
}
