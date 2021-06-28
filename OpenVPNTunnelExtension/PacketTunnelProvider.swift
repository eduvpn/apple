//
//  PacketTunnelProvider.swift
//  EduVPNTunnelExtension-macOS
//

import TunnelKit
import NetworkExtension

#if os(macOS)
enum PacketTunnelProviderError: Error {
    case connectionAttemptFromOSNotAllowed
}
#endif

class PacketTunnelProvider: OpenVPNTunnelProvider {

    #if os(macOS)
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
    #endif

}
