//
//  Shared.swift
//  EduVPN
//
//  Copyright © 2021 The Commons Conservancy. All rights reserved.
//

import Foundation

enum TunnelMessageCode: UInt8 {
    case getTransferredByteCount = 0 // Returns TransferredByteCount as Data
    case getNetworkAddresses = 1 // Returns [String] as JSON
    case getLog = 2 // Returns UTF-8 string

    var data: Data { Data([rawValue]) }
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
