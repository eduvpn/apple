//
//  Shared.swift
//  EduVPN
//
//  Copyright © 2021 The Commons Conservancy. All rights reserved.
//

import Foundation
import NetworkExtension

enum VPNProtocol: String {
    case openVPN = "OpenVPN"
    case wireGuard = "WireGuard"
}

enum TunnelMessageCode: UInt8 {
    case getTransferredByteCount = 0 // Returns TransferredByteCount as Data
    case getNetworkAddresses = 1 // Returns [String] as JSON
    case getLog = 2 // Returns UTF-8 string
    case getConnectedDate = 3 // Returns UInt64 as Data

    var data: Data { Data([rawValue]) }
}

extension Date {
    func toData() -> Data {
        var secondsSince1970 = UInt64(self.timeIntervalSince1970)
        let data: Data = withUnsafeBytes(of: &secondsSince1970) { Data($0) }
        return data
    }

    init(fromData data: Data) {
        let secondsSince1970: UInt64 = data.withUnsafeBytes { $0.load(as: UInt64.self) }
        self = Date(timeIntervalSince1970: TimeInterval(secondsSince1970))
    }
}

struct TransferredByteCount: Codable {
    let inbound: UInt64
    let outbound: UInt64

    var data: Data {
        var serialized = Data()
        for value in [inbound, outbound] {
            var localValue = value
            let buffer = withUnsafePointer(to: &localValue) {
                return UnsafeBufferPointer(start: $0, count: 1)
            }
            serialized.append(buffer)
        }
        return serialized
    }

    init(from data: Data) {
        self = data.withUnsafeBytes { pointer -> TransferredByteCount in
            // Data is 16 bytes: low 8 = received, high 8 = sent.
            let inbound = pointer.load(fromByteOffset: 0, as: UInt64.self)
            let outbound = pointer.load(fromByteOffset: 8, as: UInt64.self)
            return TransferredByteCount(inbound: inbound, outbound: outbound)
        }
    }

    init(inbound: UInt64, outbound: UInt64) {
        self.inbound = inbound
        self.outbound = outbound
    }
}

enum ProviderConfigurationKeys: String {
    case vpnProtocol // A value of type VPNProtocol
    case wireGuardConfig // wg-quick format
    case tunnelKitOpenVPNProviderConfig // json format
    case appGroup
#if os(macOS)
    case shouldPreventAutomaticConnections // Bool as NSNumber
    case password
#endif
}

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

    // shouldPreventAutomaticConnections:
    // If set, the tunnel connects only when triggered from the app.
    // When TunnelKit tries to reconnect, or when the OS triggers a
    // connection because of on-demand, the connection fails early.

#if os(macOS)
    var shouldPreventAutomaticConnections: Bool {
        get {
            if let boolNumber = providerConfiguration?[ProviderConfigurationKeys.shouldPreventAutomaticConnections.rawValue] as? NSNumber {
                return boolNumber.boolValue
            }
            return false
        }
        set(value) {
            let boolNumber = NSNumber(value: value)
            providerConfiguration?[ProviderConfigurationKeys.shouldPreventAutomaticConnections.rawValue] = boolNumber
        }
    }
#endif

    // vpnProtocol:
    // The VPN protocol used. Either .wireGuard or .openVPN.

    var vpnProtocol: VPNProtocol? {
        guard let vpnProtocolString = providerConfiguration?[ProviderConfigurationKeys.vpnProtocol.rawValue] as? String else {
            return nil
        }
        return VPNProtocol(rawValue: vpnProtocolString)
    }
}
