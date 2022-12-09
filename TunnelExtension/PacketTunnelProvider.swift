//
//  PacketTunnelProvider.swift
//  TunnelExtension
//
//  Copyright © 2020-2021 The Commons Conservancy. All rights reserved.
//

import NetworkExtension

enum PacketTunnelProviderError: Error {
    case savedProtocolConfigurationIsInvalid
    case adapterError(Error)

#if os(macOS)
    case connectionAttemptFromOSNotAllowed
#endif
}

protocol TunnelAdapterInterface: AnyObject {
    func start(packetTunnelProvider: NEPacketTunnelProvider, options: StartTunnelOptions, completionHandler: @escaping (Error?) -> Void)
    func stop(completionHandler: @escaping (Error?) -> Void)
    func wake()
    func sleep(completionHandler: @escaping () -> Void)
    func getTransferredByteCount(completionHandler: @escaping (TransferredByteCount?) -> Void)
    func networkAddresses() -> [String]?
}

class PacketTunnelProvider: NEPacketTunnelProvider {

    var adapterInterface: TunnelAdapterInterface?
    var logger: Logger?
    var connectedDate: Date?

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

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        guard let protocolConfiguration = self.protocolConfiguration as? NETunnelProviderProtocol,
              let providerConfiguration = protocolConfiguration.providerConfiguration,
              let appGroup = providerConfiguration[ProviderConfigurationKeys.appGroup.rawValue] as? String else {
            NSLog("Invalid provider configuration for the tunnel")
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

        let logger = Logger(appGroup: appGroup,
                            logSeparator: "--- EOF ---",
                            isStartedByApp: startTunnelOptions.isStartedByApp,
                            logFileName: "debug.log")
        logger.logAppVersion()
        self.logger = logger

        let adapterInterface: TunnelAdapterInterface
        if let wgQuickConfig = providerConfiguration[ProviderConfigurationKeys.wireGuardConfig.rawValue] as? String {
            guard let wgAdapterInterface = WireGuardAdapterInterface(wgQuickConfig: wgQuickConfig, logger: logger) else {
                logger.log("WireGuard config not parseable")
                completionHandler(PacketTunnelProviderError.savedProtocolConfigurationIsInvalid)
                return
            }
            adapterInterface = wgAdapterInterface
        } else if let tunnelKitConfigJson = providerConfiguration[ProviderConfigurationKeys.tunnelKitOpenVPNProviderConfig.rawValue] as? Data {
            guard let openVPNAdapterInterface = OpenVPNAdapterInterface(tunnelKitConfigJson: tunnelKitConfigJson, credentials: nil /*TODO*/, logger: logger) else {
                logger.log("TunnelKit OpenVPN provider config (JSON) not parseable")
                completionHandler(PacketTunnelProviderError.savedProtocolConfigurationIsInvalid)
                return
            }
            adapterInterface = openVPNAdapterInterface
        } else {
            logger.log("No VPN config is available")
            completionHandler(PacketTunnelProviderError.savedProtocolConfigurationIsInvalid)
            return
        }
        self.adapterInterface = adapterInterface

        adapterInterface.start(packetTunnelProvider: self, options: startTunnelOptions) { error in
            if let error = error {
                logger.log("Error while starting tunnel: \(error.localizedDescription)")
            }
            self.connectedDate = Date()
            completionHandler(error)
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        logger?.log("Stopping tunnel")

        adapterInterface?.stop { error in
            if let error = error {
                NSLog("Failed to stop adapter: \(error.localizedDescription)")
            }
            self.logger?.flushToDisk()
            completionHandler()

            #if os(macOS)
            // HACK: We have to kill the tunnel process ourselves because of a macOS bug
            exit(0)
            #endif
        }
    }

    override func wake() {
        adapterInterface?.wake()
    }

    override func sleep(completionHandler: @escaping () -> Void) {
        adapterInterface?.sleep(completionHandler: completionHandler)
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)? = nil) {
        guard messageData.count == 1, let code = TunnelMessageCode(rawValue: messageData[0]) else {
            completionHandler?(nil)
            return
        }

        switch code {
        case .getTransferredByteCount:
            adapterInterface?.getTransferredByteCount { transferredByteCount in
                completionHandler?(transferredByteCount?.data)
            }
        case .getNetworkAddresses:
            guard let addresses = adapterInterface?.networkAddresses() else {
                completionHandler?(nil)
                return
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
