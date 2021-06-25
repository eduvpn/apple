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

    private lazy var adapter: WireGuardAdapter = {
        return WireGuardAdapter(with: self) { _, message in
            self.logger?.log(message)
        }
    }()

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        guard let protocolConfiguration = self.protocolConfiguration as? NETunnelProviderProtocol,
              let providerConfiguration = protocolConfiguration.providerConfiguration,
              let wgQuickConfig = providerConfiguration["WireGuardConfig"] as? String,
              let appGroup = providerConfiguration["AppGroup"] as? String else {
            NSLog("Invalid provider configuration for the WireGuard tunnel")
            completionHandler(PacketTunnelProviderError.savedProtocolConfigurationIsInvalid)
            return
        }

        let logger = Logger(appGroup: appGroup, separator: "--- EOF ---", logFileName: "debug.log")
        self.logger = logger

        logger.log("Starting WireGuard tunnel")

        guard let tunnelConfiguration = try? TunnelConfiguration(fromWgQuickConfig: wgQuickConfig) else {
            logger.log("WireGuard config not parseable")
            completionHandler(PacketTunnelProviderError.savedProtocolConfigurationIsInvalid)
            return
        }

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
            // exit(0)
            #endif
        }
    }
}

