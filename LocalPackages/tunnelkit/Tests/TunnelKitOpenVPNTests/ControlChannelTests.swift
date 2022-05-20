//
//  ControlChannelTests.swift
//  TunnelKitOpenVPNTests
//
//  Created by Davide De Rosa on 9/10/18.
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
@testable import TunnelKitOpenVPNCore
@testable import TunnelKitOpenVPNProtocol
@testable import TunnelKitOpenVPNAppExtension
import CTunnelKitCore
import CTunnelKitOpenVPNProtocol

class ControlChannelTests: XCTestCase {
    private let hex = "634a4d2d459d606c8e6abbec168fdcd1871462eaa2eaed84c8f403bdf8c7da737d81b5774cc35fe0a42b38aa053f1335fd4a22d721880433bbb20ae1f2d88315b2d186b3b377685506fa39d85d38da16c2ecc0d631bda64f9d8f5a8d073f18aab97ade23e49ea9e7de86784d1ed5fa356df5f7fa1d163e5537efa8d4ba61239dc301a9aa55de0e06e33a7545f7d0cc153405576464ba92942dafa5fb79c7a60663ff1e7da3122ae09d4561653bef3eeb312ad68b191e2f94cbcf4e21caff0b59f8be86567bd21787070c2dc10a8baf7e87ce2e07d7d7de25ead11bd6d6e6ec030c0a3fd50d2d0ca3c0378022bb642e954868d7b93e18a131ecbb12b0bbedb1ce"
//    private let key = Data(hex: "b2d186b3b377685506fa39d85d38da16c2ecc0d6")

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

//    38 // HARD_RESET
//    858fe14742fdae40 // session_id
//    e67c9137933a412a711c0d0514aca6db6476d17d // hmac
//    000000015b96c947 // replay packet_id (seq + timestamp)
//    00 // ack_size
//    00000000 // message packet_id (HARD_RESET -> UInt32(0))
    func testHMAC() {
        let key = OpenVPN.StaticKey(biData: Data(hex: hex))
        let server = CryptoBox(cipherAlgorithm: nil, digestAlgorithm: OpenVPN.Digest.sha1.rawValue)
        XCTAssertNoThrow(try server.configure(withCipherEncKey: nil, cipherDecKey: nil, hmacEncKey: key.hmacReceiveKey, hmacDecKey: key.hmacSendKey))
        
//        let original = Data(hex: "38858fe14742fdae40e67c9137933a412a711c0d0514aca6db6476d17d000000015b96c9470000000000")
        let hmac = Data(hex: "e67c9137933a412a711c0d0514aca6db6476d17d")
        let subject = Data(hex: "000000015b96c94738858fe14742fdae400000000000")
        let data = hmac + subject
        print(data.toHex())
        
        XCTAssertNoThrow(try server.decrypter().verifyData(data, flags: nil))
    }
    
//    38 // HARD_RESET
//    bccfd171ce22e085 // session_id
//    e01a3454c354f3c3093b00fc8d6228a8b69ef503d56f6a572ebd26a800711b4cd4df2b9daf06cb90f82379e7815e39fb73be4ac5461752db4f35120474af82b2 // hmac
//    000000015b93b65d // replay packet_id
//    00 // ack_size
//    00000000 // message packet_id
    func testAuth() {
        let client = try! OpenVPN.ControlChannel.AuthSerializer(withKey: OpenVPN.StaticKey(data: Data(hex: hex), direction: .client), digest: .sha512)
        let server = try! OpenVPN.ControlChannel.AuthSerializer(withKey: OpenVPN.StaticKey(data: Data(hex: hex), direction: .server), digest: .sha512)
        
//        let original = Data(hex: "38bccfd1")
        let original = Data(hex: "38bccfd171ce22e085e01a3454c354f3c3093b00fc8d6228a8b69ef503d56f6a572ebd26a800711b4cd4df2b9daf06cb90f82379e7815e39fb73be4ac5461752db4f35120474af82b2000000015b93b65d0000000000")
        let timestamp = UInt32(0x5b93b65d)
        
        let packet: ControlPacket
        do {
            packet = try client.deserialize(data: original, start: 0, end: nil)
        } catch let e {
            XCTAssertNil(e)
            return
        }
        XCTAssertEqual(packet.code, .hardResetClientV2)
        XCTAssertEqual(packet.sessionId, Data(hex: "bccfd171ce22e085"))
        XCTAssertNil(packet.ackIds)
        XCTAssertEqual(packet.packetId, 0)
        
        let raw: Data
        do {
            raw = try server.serialize(packet: packet, timestamp: timestamp)
        } catch let e {
            XCTAssertNil(e)
            return
        }
        print("raw: \(raw.toHex())")
        print("org: \(original.toHex())")
        XCTAssertEqual(raw, original)
    }

    func testCrypt() {
        let client = try! OpenVPN.ControlChannel.CryptSerializer(withKey: OpenVPN.StaticKey(data: Data(hex: hex), direction: .client))
        let server = try! OpenVPN.ControlChannel.CryptSerializer(withKey: OpenVPN.StaticKey(data: Data(hex: hex), direction: .server))

        let original = Data(hex: "407bf3d6a260e6476d000000015ba4155887940856ddb70e01693980c5c955cb5506ecf9fd3e0bcee0c802ec269427d43bf1cda1837ffbf30c83cacff852cd0b7f4c")
        let timestamp = UInt32(0x5ba41558)
        
        let packet: ControlPacket
        do {
            packet = try client.deserialize(data: original, start: 0, end: nil)
        } catch let e {
            XCTAssertNil(e)
            return
        }
        XCTAssertEqual(packet.code, .hardResetServerV2)
        XCTAssertEqual(packet.sessionId, Data(hex: "7bf3d6a260e6476d"))
        XCTAssertEqual(packet.ackIds?.count, 1)
        XCTAssertEqual(packet.ackRemoteSessionId, Data(hex: "a62ec85cc767f0a6"))
        XCTAssertEqual(packet.packetId, 0)

        let raw: Data
        do {
            raw = try server.serialize(packet: packet, timestamp: timestamp)
        } catch let e {
            XCTAssertNil(e)
            return
        }
        print("raw: \(raw.toHex())")
        print("org: \(original.toHex())")
        XCTAssertEqual(raw, original)
    }
}
