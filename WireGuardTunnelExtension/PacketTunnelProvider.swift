//
//  PacketTunnelProvider.swift
//  WireGuardTunnelExtension-macOS
//
//  Created by Roopesh Chander on 26/05/21.
//  Copyright © 2021 SURFNet. All rights reserved.
//

import NetworkExtension
import WireGuardKit

enum PacketTunnelProviderError: Error {
    case savedProtocolConfigurationIsInvalid
    case wireGuardAdapterError(WireGuardAdapterError)
}

class PacketTunnelProvider: NEPacketTunnelProvider {

    private lazy var adapter: WireGuardAdapter = {
        return WireGuardAdapter(with: self) { _, message in
            NSLog("WireGuard-eduVPN: %@", message)
        }
    }()

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        NSLog("WireGuard-eduVPN: Starting tunnel")

        guard let protocolConfiguration = self.protocolConfiguration as? NETunnelProviderProtocol,
              let providerConfiguration = protocolConfiguration.providerConfiguration,
              let wgQuickConfig = providerConfiguration["WireGuardConfig"] as? String else {
            NSLog("WireGuard-eduVPN: WireGuard config not found")
            completionHandler(PacketTunnelProviderError.savedProtocolConfigurationIsInvalid)
            return
        }

        guard let tunnelConfiguration = try? TunnelConfiguration(fromWgQuickConfig: wgQuickConfig) else {
            NSLog("WireGuard-eduVPN: WireGuard config not parseable")
            completionHandler(PacketTunnelProviderError.savedProtocolConfigurationIsInvalid)
            return
        }

        adapter.start(tunnelConfiguration: tunnelConfiguration) { adapterError in
            if let adapterError = adapterError {
                NSLog("WireGuard-eduVPN: WireGuard adapter error: \(adapterError.localizedDescription)")
            } else {
                let interfaceName = self.adapter.interfaceName ?? "unknown"
                NSLog("WireGuard-eduVPN: Tunnel interface is %@", interfaceName)
            }
            completionHandler(adapterError)
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        NSLog("WireGuard-eduVPN: Stopping tunnel")
        adapter.stop { error in
            if let error = error {
                NSLog("WireGuard-eduVPN: Failed to stop WireGuard adapter: \(error.localizedDescription)")
            }
            completionHandler()

            #if os(macOS)
            // HACK: We have to kill the tunnel process ourselves because of a macOS bug
            exit(0)
            #endif
        }
        completionHandler()
    }
}
