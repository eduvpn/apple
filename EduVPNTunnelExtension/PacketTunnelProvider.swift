//
//  PacketTunnelProvider.swift
//  eduVPNTunnelExtension
//

import TunnelKit

class PacketTunnelProvider: OpenVPNTunnelProvider {
    override init() {
        super.init()
        super.setWaitForLinkAvailabilityAfterLinkFailure(enabled: true)
    }
}
