//
//  PacketTunnelProvider.swift
//  EduVPNTunnelExtension-macOS
//

import TunnelKit

class PacketTunnelProvider: OpenVPNTunnelProvider {
    override func startTunnel(options: [String: NSObject]? = nil, completionHandler: @escaping (Error?) -> Void) {
        let assistPathUpgradingWithPathMonitor = (options?["assistPathUpgradingWithPathMonitor"] as? NSNumber)?.boolValue ?? false
        if assistPathUpgradingWithPathMonitor {
            setPathMonitorUsageMode(.assistPathUpgrading)
        }
        super.startTunnel(options: options, completionHandler: completionHandler)
    }
}
