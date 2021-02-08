//
//  PacketTunnelProvider.swift
//  EduVPNTunnelExtension-macOS
//

import TunnelKit
import NetworkExtension

enum PacketTunnelProviderError: Error {
    case connectionAttemptFromOSNotAllowed
}

class PacketTunnelProvider: OpenVPNTunnelProvider {
    override var reasserting: Bool {
        didSet {
            if reasserting {
                if let tunnelProtocol = protocolConfiguration as? NETunnelProviderProtocol {
                    if tunnelProtocol.shouldPreventAutomaticConnections {
                        stopTunnel(with: .none, completionHandler: {})
                    }
                }
            }
        }
    }

    override func startTunnel(options: [String: NSObject]? = nil, completionHandler: @escaping (Error?) -> Void) {
        let startTunnelOptions = StartTunnelOptions(options: options ?? [:])
        if !startTunnelOptions.isStartedByApp {
            if let tunnelProtocol = protocolConfiguration as? NETunnelProviderProtocol {
                if tunnelProtocol.shouldPreventAutomaticConnections {
                    Darwin.sleep(3) // Prevent rapid connect-disconnect cycles
                    completionHandler(PacketTunnelProviderError.connectionAttemptFromOSNotAllowed)
                    return
                }
            }
        }

        super.startTunnel(options: options, completionHandler: completionHandler)
    }
}
