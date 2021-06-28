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

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)? = nil) {
        // Convert TunnelKit's response to our response
        guard messageData.count == 1, let code = TunnelMessageCode(rawValue: messageData[0]) else {
            completionHandler?(nil)
            return
        }

        let encoder = JSONEncoder()
        switch code {
        case .getTransferredByteCount:
            super.handleAppMessage(
                OpenVPNTunnelProvider.Message.dataCount.data,
                completionHandler: completionHandler)
        case .getNetworkAddresses:
            super.handleAppMessage(OpenVPNTunnelProvider.Message.serverConfiguration.data) { data in
                guard let data = data else {
                    completionHandler?(nil)
                    return
                }
                var addresses: [String] = []
                if let config = try? JSONDecoder().decode(OpenVPN.Configuration.self, from: data) {
                    if let ipv4Address = config.ipv4?.address {
                        addresses.append(ipv4Address)
                    }
                    if let ipv6Address = config.ipv6?.address {
                        addresses.append(ipv6Address)
                    }
                }
                completionHandler?(try? encoder.encode(addresses))
            }
        case .getLog:
            super.handleAppMessage(
                OpenVPNTunnelProvider.Message.requestLog.data,
                completionHandler: completionHandler)
        }
    }
}
