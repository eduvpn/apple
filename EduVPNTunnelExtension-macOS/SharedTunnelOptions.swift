//
//  SharedTunnelOptions.swift
//  EduVPN

// Options on the tunnel that are used in both the main app and the tunnel extension

import Foundation
import NetworkExtension

#if os(macOS)
struct StartTunnelOptions {
    static let isStartedByAppKey = "isStartedByApp"

    private(set) var options: [String: Any]

    var isStartedByApp: Bool {
        get {
            if let boolNumber = options[Self.isStartedByAppKey] as? NSNumber {
                return boolNumber.boolValue
            }
            return false
        }
        set(value) {
            let boolNumber = NSNumber(value: value)
            options[Self.isStartedByAppKey] = boolNumber
        }
    }

    init(options: [String: Any]) {
        self.options = options
    }

    init(isStartedByApp: Bool) {
        self.options = [Self.isStartedByAppKey: NSNumber(value: isStartedByApp)]
    }
}

extension NETunnelProviderProtocol {
    struct SharedKeys {
        // If set, the tunnel connects only when triggered from the app.
        // When TunnelKit tries to reconnect, or when the OS triggers a
        // connection because of on-demand, the connection fails early.
        static let shouldPreventAutomaticConnectionsKey = "shouldPreventAutomaticConnections"
    }

    var shouldPreventAutomaticConnections: Bool {
        get {
            if let boolNumber = providerConfiguration?[SharedKeys.shouldPreventAutomaticConnectionsKey] as? NSNumber {
                return boolNumber.boolValue
            }
            return false
        }
        set(value) {
            let boolNumber = NSNumber(value: value)
            providerConfiguration?[SharedKeys.shouldPreventAutomaticConnectionsKey] = boolNumber
        }
    }
}
#endif
