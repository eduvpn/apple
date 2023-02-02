//
//  PacketTunnelProvider.swift
//  EduVPNTunnelExtension-macOS
//

import TunnelKitOpenVPNAppExtension
import TunnelKitOpenVPNManager
import TunnelKitOpenVPNCore
import TunnelKitCore
import TunnelKitAppExtension
import TunnelKitManager
import NetworkExtension
import SwiftyBeaver

enum PacketTunnelProviderError: Error {
    case savedProtocolConfigurationIsInvalid
    case openVPNAdapterError(Error)

#if os(macOS)
    case connectionAttemptFromOSNotAllowed
#endif
}

class PacketTunnelProvider: NEPacketTunnelProvider {

    private lazy var adapter = OpenVPNAdapter(with: self, flushLogHandler: { self.logger?.flushToDisk() })

    var connectedDate: Date?
    var logger: Logger?

    override var reasserting: Bool {
        didSet {
            #if os(macOS)
            if reasserting {
                if let tunnelProtocol = protocolConfiguration as? NETunnelProviderProtocol {
                    if tunnelProtocol.shouldPreventAutomaticConnections {
                        stopTunnel(with: .none, completionHandler: {})
                    }
                }
            }
            #endif
            if reasserting {
                connectedDate = nil
            } else {
                connectedDate = Date()
            }
        }
    }

    override func startTunnel(options: [String: NSObject]? = nil, completionHandler: @escaping (Error?) -> Void) {
        guard let protocolConfiguration = self.protocolConfiguration as? NETunnelProviderProtocol,
              let providerConfiguration = protocolConfiguration.providerConfiguration,
              let providerConfigJson = providerConfiguration[ProviderConfigurationKeys.tunnelKitOpenVPNProviderConfig.rawValue] as? Data,
              let providerConfig = try? JSONDecoder().decode(OpenVPN.ProviderConfiguration.self, from: providerConfigJson),
              let appGroup = providerConfiguration[ProviderConfigurationKeys.appGroup.rawValue] as? String else {
            NSLog("Invalid provider configuration for the OpenVPN tunnel")
            completionHandler(PacketTunnelProviderError.savedProtocolConfigurationIsInvalid)
            return
        }

        let startTunnelOptions = StartTunnelOptions(options: options ?? [:])

#if os(macOS)
        if !startTunnelOptions.isStartedByApp {
            if protocolConfiguration.shouldPreventAutomaticConnections {
                Darwin.sleep(3) // Prevent rapid connect-disconnect cycles
                completionHandler(PacketTunnelProviderError.connectionAttemptFromOSNotAllowed)
                return
            }
        }
#endif

        // Setup logging

        let logger = Logger(appGroup: appGroup,
                            logSeparator: "--- EOF ---",
                            isStartedByApp: startTunnelOptions.isStartedByApp,
                            logFileName: "debug.log")
        self.logger = logger

        logger.log("Starting OpenVPN tunnel")
        logger.logAppVersion()

        let loggerDestination = LoggerDestination(logger: logger)
        loggerDestination.minLevel = .debug
        loggerDestination.format = "$Dyyyy-MM-dd HH:mm:ss.SSS$d $L $N.$F:$l - $M"
        SwiftyBeaver.addDestination(loggerDestination)

        CoreConfiguration.masksPrivateData = providerConfig.masksPrivateData

        // Set credentials

        let credentials: OpenVPN.Credentials?
        if let username = protocolConfiguration.username, let passwordReference = protocolConfiguration.passwordReference {
            guard let password = try? Keychain.password(forReference: passwordReference) else {
                completionHandler(OpenVPNProviderConfigurationError.credentials(details: "Keychain.password(forReference:)"))
                return
            }
            credentials = OpenVPN.Credentials(username, password)
        } else {
            credentials = nil
        }

        // Start the tunnel

        var appVersionString = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown version"
        if let appBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            appVersionString += " (\(appBuild))"
        }
        adapter.appVersion = appVersionString

        if !startTunnelOptions.isStartedByApp {
            adapter.authFailShutdownHandler = { [weak self] in
                // Using deprecated call because there's no alternative
                self?.displayMessage(
                    """
                    VPN authentication failed. You can re-authenticate your VPN
                    connection in the app by turning it off, and then back on.
                    """,
                    completionHandler: { _ in })
            }
        }

        adapter.start(providerConfiguration: providerConfig, credentials: credentials, completionHandler: completionHandler)
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        adapter.stop {
            completionHandler()
#if os(macOS)
            exit(0)
#endif
        }
    }

    override func wake() {
#if os(iOS)
        // Nothing to do
#else
        adapter.resume()
#endif
    }

    override func sleep(completionHandler: @escaping () -> Void) {
#if os(iOS)
        // Nothing to do
        completionHandler()
#else
        adapter.pause(completionHandler: completionHandler)
#endif
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)? = nil) {
        guard messageData.count == 1, let code = TunnelMessageCode(rawValue: messageData[0]) else {
            completionHandler?(nil)
            return
        }

        switch code {
        case .getTransferredByteCount:
            guard let dataCount = adapter.dataCount() else {
                completionHandler?(nil)
                return
            }
            let transferred = TransferredByteCount(inbound: UInt64(dataCount.received), outbound: UInt64(dataCount.sent))
            completionHandler?(transferred.data)
        case .getNetworkAddresses:
            guard let serverConfiguration = adapter.serverConfiguration() else {
                completionHandler?(nil)
                return
            }
            var addresses: [String] = []
            if let ipv4Address = serverConfiguration.ipv4?.address {
                addresses.append(ipv4Address)
            }
            if let ipv6Address = serverConfiguration.ipv6?.address {
                addresses.append(ipv6Address)
            }
            let encoder = JSONEncoder()
            completionHandler?(try? encoder.encode(addresses))
        case .getLog:
            var data = Data()
            for line in (logger?.lines ?? []) {
                data.append(line.data(using: .utf8) ?? Data())
                data.append("\n".data(using: .utf8) ?? Data())
            }
            completionHandler?(data)
        case .getConnectedDate:
            completionHandler?(connectedDate?.toData())
        }
    }
}

class LoggerDestination: BaseDestination {
    private let logger: Logger

    init(logger: Logger) {
        self.logger = logger
        super.init()
    }

    override open func send(_ level: SwiftyBeaver.Level, msg: String, thread: String,
                            file: String, function: String, line: Int, context: Any? = nil) -> String? {
        if let formattedString = super.send(level, msg: msg, thread: thread, file: file, function: function, line: line, context: context) {
            logger.log(formattedString)
            return formattedString
        }
        return nil
    }
}
