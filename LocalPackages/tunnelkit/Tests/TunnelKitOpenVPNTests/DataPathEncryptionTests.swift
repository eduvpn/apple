//
//  DataPathEncryptionTests.swift
//  TunnelKitOpenVPNTests
//
//  Created by Davide De Rosa on 7/11/18.
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
//      Copyright (c) 2018-Present Private Internet Access
//
//      Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
//      The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
//      THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

import XCTest
@testable import TunnelKitCore
import CTunnelKitCore
import CTunnelKitOpenVPNProtocol

class DataPathEncryptionTests: XCTestCase {
    private let cipherKey = try! SecureRandom.safeData(length: 32)

    private let hmacKey = try! SecureRandom.safeData(length: 32)

    private var enc: DataPathEncrypter!
    
    private var dec: DataPathDecrypter!
    
    override func setUp() {
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testCBC() {
        prepareBox(cipher: "aes-128-cbc", digest: "sha256")
        privateTestDataPathHigh(peerId: nil)
        privateTestDataPathLow(peerId: nil)
    }
    
    func testFloatingCBC() {
        prepareBox(cipher: "aes-128-cbc", digest: "sha256")
        privateTestDataPathHigh(peerId: 0x64385837)
        privateTestDataPathLow(peerId: 0x64385837)
    }
    
    func testGCM() {
        prepareBox(cipher: "aes-256-gcm", digest: nil)
        privateTestDataPathHigh(peerId: nil)
        privateTestDataPathLow(peerId: nil)
    }

    func testFloatingGCM() {
        prepareBox(cipher: "aes-256-gcm", digest: nil)
        privateTestDataPathHigh(peerId: 0x64385837)
        privateTestDataPathLow(peerId: 0x64385837)
    }
    
    func prepareBox(cipher: String, digest: String?) {
        let box = CryptoBox(cipherAlgorithm: cipher, digestAlgorithm: digest)
        try! box.configure(withCipherEncKey: cipherKey, cipherDecKey: cipherKey, hmacEncKey: hmacKey, hmacDecKey: hmacKey)
        enc = box.encrypter().dataPathEncrypter()
        dec = box.decrypter().dataPathDecrypter()
    }
    
    func privateTestDataPathHigh(peerId: UInt32?) {
        let path = DataPath(
            encrypter: enc,
            decrypter: dec,
            peerId: peerId ?? PacketPeerIdDisabled,
            compressionFraming: .disabled,
            compressionAlgorithm: .disabled,
            maxPackets: 1000,
            usesReplayProtection: false
        )

        if let peerId = peerId {
            enc.setPeerId(peerId)
            dec.setPeerId(peerId)
            XCTAssertEqual(enc.peerId(), peerId & 0xffffff)
            XCTAssertEqual(dec.peerId(), peerId & 0xffffff)
        }

        let expectedPayload = Data(hex: "00112233445566778899")
        let key: UInt8 = 4

        let encrypted = try! path.encryptPackets([expectedPayload], key: key)
        print(encrypted.map { $0.toHex() })
        let decrypted = try! path.decryptPackets(encrypted, keepAlive: nil)
        print(decrypted.map { $0.toHex() })
        let payload = decrypted.first!

        XCTAssertEqual(payload, expectedPayload)
    }

    func privateTestDataPathLow(peerId: UInt32?) {
        if let peerId = peerId {
            enc.setPeerId(peerId)
            dec.setPeerId(peerId)
            XCTAssertEqual(enc.peerId(), peerId & 0xffffff)
            XCTAssertEqual(dec.peerId(), peerId & 0xffffff)
        }

        let expectedPayload = Data(hex: "00112233445566778899")
        let expectedPacketId: UInt32 = 0x56341200
        let key: UInt8 = 4

        var encryptedPacketBytes: [UInt8] = [UInt8](repeating: 0, count: 1000)
        var encryptedPacketLength: Int = 0
        enc.assembleDataPacket(nil, packetId: expectedPacketId, payload: expectedPayload, into: &encryptedPacketBytes, length: &encryptedPacketLength)
        let encrypted = try! enc.encryptedDataPacket(withKey: key, packetId: expectedPacketId, packetBytes: encryptedPacketBytes, packetLength: encryptedPacketLength)

        var decryptedBytes: [UInt8] = [UInt8](repeating: 0, count: 1000)
        var decryptedLength: Int = 0
        var packetId: UInt32 = 0
        var compressionHeader: UInt8 = 0
        try! dec.decryptDataPacket(encrypted, into: &decryptedBytes, length: &decryptedLength, packetId: &packetId)
        let payload = try! dec.parsePayload(nil, compressionHeader: &compressionHeader, packetBytes: &decryptedBytes, packetLength: decryptedLength)

        XCTAssertEqual(payload, expectedPayload)
        XCTAssertEqual(packetId, expectedPacketId)
    }
}
