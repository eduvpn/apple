//
//  PacketTunnelProvider.swift
//  WireGuardTunnelExtension-macOS
//
//  Copyright © 2020-2021 The Commons Conservancy. All rights reserved.
//

import NetworkExtension
import WireGuardKit

enum PacketTunnelProviderError: Error {
    case savedProtocolConfigurationIsInvalid
    case wireGuardAdapterError(WireGuardAdapterError)
}

class PacketTunnelProvider: NEPacketTunnelProvider {

    // Logging
    var logger: Logger?
    var tunnelConfiguration: TunnelConfiguration?

    private lazy var adapter: WireGuardAdapter = {
        return WireGuardAdapter(with: self) { _, message in
            self.logger?.log(message)
        }
    }()

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        guard let protocolConfiguration = self.protocolConfiguration as? NETunnelProviderProtocol,
              let providerConfiguration = protocolConfiguration.providerConfiguration,
              let wgQuickConfig = providerConfiguration[WireGuardProviderConfigurationKeys.wireGuardConfig.rawValue] as? String,
              let appGroup = providerConfiguration[WireGuardProviderConfigurationKeys.appGroup.rawValue] as? String else {
            NSLog("Invalid provider configuration for the WireGuard tunnel")
            completionHandler(PacketTunnelProviderError.savedProtocolConfigurationIsInvalid)
            return
        }

        let startTunnelOptions = StartTunnelOptions(options: options ?? [:])
        let logger = Logger(appGroup: appGroup,
                            logSeparator: "--- EOF ---",
                            isStartedByApp: startTunnelOptions.isStartedByApp,
                            logFileName: "debug.log")
        self.logger = logger

        logger.log("Starting WireGuard tunnel")

        guard let tunnelConfiguration = try? TunnelConfiguration(fromWgQuickConfig: wgQuickConfig) else {
            logger.log("WireGuard config not parseable")
            completionHandler(PacketTunnelProviderError.savedProtocolConfigurationIsInvalid)
            return
        }
        self.tunnelConfiguration = tunnelConfiguration

        adapter.start(tunnelConfiguration: tunnelConfiguration) { adapterError in
            if let adapterError = adapterError {
                logger.log("WireGuard adapter error: \(adapterError.localizedDescription)")
            } else {
                let interfaceName = self.adapter.interfaceName ?? "unknown"
                logger.log("Tunnel interface is \(interfaceName)")
            }
            completionHandler(adapterError)
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        logger?.log("Stopping tunnel")

        adapter.stop { error in
            if let error = error {
                NSLog("Failed to stop WireGuard adapter: \(error.localizedDescription)")
            }
            self.logger?.flushToDisk()
            completionHandler()

            #if os(macOS)
            // HACK: We have to kill the tunnel process ourselves because of a macOS bug
            exit(0)
            #endif
        }
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)? = nil) {
        guard messageData.count == 1, let code = TunnelMessageCode(rawValue: messageData[0]) else {
            completionHandler?(nil)
            return
        }

        switch code {
        case .getTransferredByteCount:
            adapter.getRuntimeConfiguration { settings in
                guard let settings = settings,
                      let runtimeConfig = try? TunnelConfiguration(fromUapiConfig: settings, basedOn: self.tunnelConfiguration) else {
                    completionHandler?(nil)
                    return
                }
                let rxBytesTotal = runtimeConfig.peers.reduce(0) { $0 + ($1.rxBytes ?? 0) }
                let txBytesTotal = runtimeConfig.peers.reduce(0) { $0 + ($1.txBytes ?? 0) }
                let transferred = TransferredByteCount(inbound: rxBytesTotal, outbound: txBytesTotal)
                completionHandler?(transferred.data)
            }
        case .getNetworkAddresses:
            guard let tunnelConfiguration = self.tunnelConfiguration else {
                completionHandler?(nil)
                return
            }
            let addresses: [String] = tunnelConfiguration.interface.addresses.map { "\($0.address)" }
            let encoder = JSONEncoder()
            completionHandler?(try? encoder.encode(addresses))
        case .getLog:
            var data = Data()
            for line in (logger?.lines ?? []) {
                data.append(line.data(using: .utf8) ?? Data())
                data.append("\n".data(using: .utf8) ?? Data())
            }
            completionHandler?(data)
        }
    }
}
