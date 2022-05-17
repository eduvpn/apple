//
//  PacketTests.swift
//  TunnelKitOpenVPNTests
//
//  Created by Davide De Rosa on 9/9/18.
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

import XCTest
@testable import TunnelKitCore
import CTunnelKitOpenVPNProtocol

class PacketTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testControlPacket() {
        let id: UInt32 = 0x1456
        let code: PacketCode = .controlV1
        let key: UInt8 = 3
        let sessionId = Data(hex: "1122334455667788")
        let payload = Data(hex: "932748238742397591704891")

        let serialized = ControlPacket(code: code, key: key, sessionId: sessionId, packetId: id, payload: payload).serialized()
        let expected = Data(hex: "2311223344556677880000001456932748238742397591704891")
        print("Serialized: \(serialized.toHex())")
        print("Expected  : \(expected.toHex())")

        XCTAssertEqual(serialized, expected)
    }

    func testAckPacket() {
        let acks: [UInt32] = [0xaa, 0xbb, 0xcc, 0xdd, 0xee]
        let key: UInt8 = 3
        let sessionId = Data(hex: "1122334455667788")
        let remoteSessionId = Data(hex: "a639328cbf03490e")

        let serialized = ControlPacket(key: key, sessionId: sessionId, ackIds: acks as [NSNumber], ackRemoteSessionId: remoteSessionId).serialized()
        let expected = Data(hex: "2b112233445566778805000000aa000000bb000000cc000000dd000000eea639328cbf03490e")
        print("Serialized: \(serialized.toHex())")
        print("Expected  : \(expected.toHex())")
        
        XCTAssertEqual(serialized, expected)
    }
}
