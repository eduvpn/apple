//
//  PacketTunnelProvider.swift
//  EduVPNTunnelExtension-macOS
//

import TunnelKit

class PacketTunnelProvider: OpenVPNTunnelProvider {
    override init() {
        super.init()
        super.setWaitForLinkAvailabilityAfterLinkFailure(enabled: true)
    }
}
