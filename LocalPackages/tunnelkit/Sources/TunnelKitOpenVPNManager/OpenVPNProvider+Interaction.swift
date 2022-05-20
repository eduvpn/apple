//
//  OpenVPNProvider+Interaction.swift
//  TunnelKit
//
//  Created by Davide De Rosa on 9/24/17.
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
//  This file incorporates work covered by the following copyright and
//  permission notice:
//

import Foundation

extension OpenVPNProvider {

    /// The messages accepted by `OpenVPNProvider`.
    public class Message: Equatable {
        
        /// Requests a snapshot of the latest debug log. Returns the log data decoded from UTF-8.
        public static let requestLog = Message(0xff)
        
        /// Requests the current bytes count from data channel (if connected).
        ///
        /// Data is 16 bytes: low 8 = received, high 8 = sent.
        public static let dataCount = Message(0xfe)
        
        /// Requests the configuration pulled from the server (if connected and available).
        ///
        /// Data is JSON (Decodable).
        public static let serverConfiguration = Message(0xfd)

        /// The underlying raw message `Data` to forward to the tunnel via IPC.
        public let data: Data
        
        private init(_ byte: UInt8) {
            data = Data([byte])
        }
        
        public init(_ data: Data) {
            self.data = data
        }
        
        // MARK: Equatable

        public static func ==(lhs: Message, rhs: Message) -> Bool {
            return (lhs.data == rhs.data)
        }
    }
}
