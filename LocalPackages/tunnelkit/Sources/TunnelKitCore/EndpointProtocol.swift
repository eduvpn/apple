//
//  EndpointProtocol.swift
//  TunnelKit
//
//  Created by Davide De Rosa on 11/10/18.
//  Copyright (c) 2021 Davide De Rosa. All rights reserved.
//
//  https://github.com/passepartoutvpn
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

import Foundation

/// Defines the communication protocol of an endpoint.
public struct EndpointProtocol: RawRepresentable, Equatable, CustomStringConvertible {
    
    /// The socket type.
    public let socketType: SocketType
    
    /// The remote port.
    public let port: UInt16
    
    public init(_ socketType: SocketType, _ port: UInt16) {
        self.socketType = socketType
        self.port = port
    }
    
    // MARK: RawRepresentable
    
    public init?(rawValue: String) {
        let components = rawValue.components(separatedBy: ":")
        guard components.count == 2 else {
            return nil
        }
        guard let socketType = SocketType(rawValue: components[0]) else {
            return nil
        }
        guard let port = UInt16(components[1]) else {
            return nil
        }
        self.init(socketType, port)
    }
    
    public var rawValue: String {
        return "\(socketType.rawValue):\(port)"
    }
    
    // MARK: Equatable
    
    public static func ==(lhs: EndpointProtocol, rhs: EndpointProtocol) -> Bool {
        return (lhs.socketType == rhs.socketType) && (lhs.port == rhs.port)
    }
    
    // MARK: CustomStringConvertible
    
    public var description: String {
        return rawValue
    }
}

extension EndpointProtocol: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        let proto = EndpointProtocol(rawValue: rawValue) ?? EndpointProtocol(.udp, 1198)
        self.init(proto.socketType, proto.port)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
