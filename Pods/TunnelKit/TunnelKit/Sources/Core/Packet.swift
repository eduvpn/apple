//
//  Packet.swift
//  TunnelKit
//
//  Created by Davide De Rosa on 2/3/17.
//  Copyright (c) 2019 Davide De Rosa. All rights reserved.
//
//  https://github.com/keeshux
//
//  This file is part of TunnelKit.
//
//  TunnelKit is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  TunnelKit is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with TunnelKit.  If not, see <http://www.gnu.org/licenses/>.
//
//  This file incorporates work covered by the following copyright and
//  permission notice:
//
//      Copyright (c) 2018-Present Private Internet Access
//
//      Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
//      The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
//      THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
//

import Foundation
import __TunnelKitNative

// TODO: convert to C for efficiency

/// Reads and writes packets as a stream. Useful for stream-oriented links (e.g TCP/IP).
public class PacketStream {
    
    /**
     Parses packets from a stream.
     
     - Parameter stream: The data stream.
     - Returns: A pair where the first value is the `Int` offset up to which
     the stream could be parsed, and the second value is an array containing
     the parsed packets up to such offset.
     */
    public static func packets(from stream: Data) -> (Int, [Data]) {
        var ni = 0
        var parsed: [Data] = []
        while (ni + 2 <= stream.count) {
            let packlen = Int(stream.networkUInt16Value(from: ni))
            let start = ni + 2
            let end = start + packlen
            guard (end <= stream.count) else {
                break
            }
            let packet = stream.subdata(offset: start, count: end - start)
            parsed.append(packet)
            ni = end
        }
        return (ni, parsed)
    }
    
    /**
     Creates a contiguous stream of packets.
     
     - Parameter packet: The packet.
     - Returns: A stream made of the packet.
     */
    public static func stream(from packet: Data) -> Data {
        var raw = Data(capacity: 2 + packet.count)
        raw.append(UInt16(packet.count).bigEndian)
        raw.append(contentsOf: packet)
        return raw
    }
    
    /**
     Creates a contiguous stream of packets.
     
     - Parameter packets: The array of packets.
     - Returns: A stream made of the array of packets.
     */
    public static func stream(from packets: [Data]) -> Data {
        var raw = Data()
        for payload in packets {
            raw.append(UInt16(payload.count).bigEndian)
            raw.append(payload)
        }
        return raw
    }
    
    private init() {
    }
}

/// :nodoc:
extension ControlPacket {

    /// :nodoc:
    open override var description: String {
        var msg: [String] = ["\(code) | \(key)"]
        msg.append("sid: \(sessionId.toHex())")
        if let ackIds = ackIds, let ackRemoteSessionId = ackRemoteSessionId {
            msg.append("acks: {\(ackIds), \(ackRemoteSessionId.toHex())}")
        }
        if !isAck {
            msg.append("pid: \(packetId)")
        }
        if let payload = payload {
            if CoreConfiguration.logsSensitiveData {
                msg.append("[\(payload.count) bytes] -> \(payload.toHex())")
            } else {
                msg.append("[\(payload.count) bytes]")
            }
        }
        return "{\(msg.joined(separator: ", "))}"
    }
}

class DataPacket {
    static let pingString = Data(hex: "2a187bf3641eb4cb07ed2d0a981fc748")
}

/// :nodoc:
extension PacketCode: CustomStringConvertible {
    public var description: String {
        switch self {
        case .softResetV1:          return "SOFT_RESET_V1"
        case .controlV1:            return "CONTROL_V1"
        case .ackV1:                return "ACK_V1"
        case .dataV1:               return "DATA_V1"
        case .hardResetClientV2:    return "HARD_RESET_CLIENT_V2"
        case .hardResetServerV2:    return "HARD_RESET_SERVER_V2"
        case .dataV2:               return "DATA_V2"
        case .unknown:              return "UNKNOWN"
        }
    }
}
