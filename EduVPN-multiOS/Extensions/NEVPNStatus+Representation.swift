//
//  NEVPNStatus+Representation.swift
//  EduVPN
//
//  Created by Johan Kool on 12/03/2020.
//  Copyright © 2020 SURFNet. All rights reserved.
//

import NetworkExtension

extension NEVPNStatus {
    var stringRepresentation: String {
        switch self {
        case .connected:
            return "Connected"
        case .connecting:
            return "Connecting"
        case .disconnected:
            return "Disconnected"
        case .disconnecting:
            return "Disconnecting"
        case .invalid:
            return "Invalid"
        case .reasserting:
            return "Reasserting"
        @unknown default:
            fatalError()
        }
    }
}
