//
//  EncryptionTests.swift
//  TunnelKitOpenVPNTests
//
//  Created by Davide De Rosa on 7/7/18.
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
@testable import TunnelKitOpenVPNCore
import CTunnelKitCore
import CTunnelKitOpenVPNProtocol

class EncryptionTests: XCTestCase {
    private var cipherEncKey: ZeroingData!

    private var cipherDecKey: ZeroingData!
    
    private var hmacEncKey: ZeroingData!
    
    private var hmacDecKey: ZeroingData!
    
    override func setUp() {
        cipherEncKey = try! SecureRandom.safeData(length: 32)
        cipherDecKey = try! SecureRandom.safeData(length: 32)
        hmacEncKey = try! SecureRandom.safeData(length: 32)
        hmacDecKey = try! SecureRandom.safeData(length: 32)
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testCBC() {
        let (client, server) = clientServer("aes-128-cbc", "sha256")

        let plain = Data(hex: "00112233445566778899")
        let encrypted = try! client.encrypter().encryptData(plain, flags: nil)
        let decrypted = try! server.decrypter().decryptData(encrypted, flags: nil)
        XCTAssertEqual(plain, decrypted)
    }

    func testHMAC() {
        let (client, server) = clientServer(nil, "sha256")

        let plain = Data(hex: "00112233445566778899")
        let encrypted = try! client.encrypter().encryptData(plain, flags: nil)
        XCTAssertNoThrow(try server.decrypter().verifyData(encrypted, flags: nil))
    }
    
    func testGCM() {
        let (client, server) = clientServer("aes-256-gcm", nil)
        
        let packetId: [UInt8] = [0x56, 0x34, 0x12, 0x00]
        let ad: [UInt8] = [0x00, 0x12, 0x34, 0x56]
        var flags = packetId.withUnsafeBufferPointer { (iv) in
            return ad.withUnsafeBufferPointer { (ad) in
                return CryptoFlags(iv: iv.baseAddress, ivLength: packetId.count, ad: ad.baseAddress, adLength: ad.count)
            }
        }
        let plain = Data(hex: "00112233445566778899")
        let encrypted = try! client.encrypter().encryptData(plain, flags: &flags)
        let decrypted = try! server.decrypter().decryptData(encrypted, flags: &flags)
        XCTAssertEqual(plain, decrypted)
    }
    
    func testCTR() {
        let (client, server) = clientServer("aes-256-ctr", "sha256")

        let original = Data(hex: "0000000000")
        let ad: [UInt8] = [UInt8](Data(hex: "38afa8f1162096081e000000015ba35373"))
        var flags = ad.withUnsafeBufferPointer {
            CryptoFlags(iv: nil, ivLength: 0, ad: $0.baseAddress, adLength: ad.count)
        }

//        let expEncrypted = Data(hex: "319bb8e7f8f7930cc4625079dd32a6ef9540c2fc001c53f909f712037ae9818af840b88714")
        let encrypted = try! client.encrypter().encryptData(original, flags: &flags)
        print(encrypted.toHex())
//        XCTAssertEqual(encrypted, expEncrypted)

        let decrypted = try! server.decrypter().decryptData(encrypted, flags: &flags)
        print(decrypted.toHex())
        XCTAssertEqual(decrypted, original)
    }

    func testCertificateMD5() {
        let path = Bundle.module.path(forResource: "pia-2048", ofType: "pem")!
        let md5 = try! TLSBox.md5(forCertificatePath: path)
        let exp = "e2fccccaba712ccc68449b1c56427ac1"
        print(md5)
        XCTAssertEqual(md5, exp)
    }
    
    func testPrivateKeyDecryption() {
        privateTestPrivateKeyDecryption(pkcs: "1")
        privateTestPrivateKeyDecryption(pkcs: "8")
    }
    
    private func privateTestPrivateKeyDecryption(pkcs: String) {
        let bundle = Bundle.module
        let encryptedPath = bundle.path(forResource: "tunnelbear", ofType: "enc.\(pkcs).key")!
        let decryptedPath = bundle.path(forResource: "tunnelbear", ofType: "key")!
        
        XCTAssertThrowsError(try TLSBox.decryptedPrivateKey(fromPath: encryptedPath, passphrase: "wrongone"))
        let decryptedViaPath = try! TLSBox.decryptedPrivateKey(fromPath: encryptedPath, passphrase: "foobar")
        print(decryptedViaPath)
        let encryptedPEM = try! String(contentsOfFile: encryptedPath, encoding: .utf8)
        let decryptedViaString = try! TLSBox.decryptedPrivateKey(fromPEM: encryptedPEM, passphrase: "foobar")
        print(decryptedViaString)
        XCTAssertEqual(decryptedViaPath, decryptedViaString)
        
        let expDecrypted = try! String(contentsOfFile: decryptedPath)
        XCTAssertEqual(decryptedViaPath, expDecrypted)
    }
    
    func testCertificatePreamble() {
        let url = Bundle.module.url(forResource: "tunnelbear", withExtension: "crt")!
        let cert = OpenVPN.CryptoContainer(pem: try! String(contentsOf: url))
        XCTAssert(cert.pem.hasPrefix("-----BEGIN"))
    }
    
    private func clientServer(_ c: String?, _ d: String?) -> (CryptoBox, CryptoBox) {
        let client = CryptoBox(cipherAlgorithm: c, digestAlgorithm: d)
        let server = CryptoBox(cipherAlgorithm: c, digestAlgorithm: d)
        XCTAssertNoThrow(try client.configure(withCipherEncKey: cipherEncKey, cipherDecKey: cipherDecKey, hmacEncKey: hmacEncKey, hmacDecKey: hmacDecKey))
        XCTAssertNoThrow(try server.configure(withCipherEncKey: cipherDecKey, cipherDecKey: cipherEncKey, hmacEncKey: hmacDecKey, hmacDecKey: hmacEncKey))
        return (client, server)
    }
}
