//
//  EncryptionPerformanceTests.swift
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
import CTunnelKitCore
import CTunnelKitOpenVPNProtocol

class EncryptionPerformanceTests: XCTestCase {
    private var cbcEncrypter: Encrypter!
    
    private var cbcDecrypter: Decrypter!
    
    private var gcmEncrypter: Encrypter!
    
    private var gcmDecrypter: Decrypter!
    
    override func setUp() {
        let cipherKey = try! SecureRandom.safeData(length: 32)
        let hmacKey = try! SecureRandom.safeData(length: 32)
        
        let cbc = CryptoBox(cipherAlgorithm: "aes-128-cbc", digestAlgorithm: "sha1")
        try! cbc.configure(withCipherEncKey: cipherKey, cipherDecKey: cipherKey, hmacEncKey: hmacKey, hmacDecKey: hmacKey)
        cbcEncrypter = cbc.encrypter()
        cbcDecrypter = cbc.decrypter()

        let gcm = CryptoBox(cipherAlgorithm: "aes-128-gcm", digestAlgorithm: nil)
        try! gcm.configure(withCipherEncKey: cipherKey, cipherDecKey: cipherKey, hmacEncKey: hmacKey, hmacDecKey: hmacKey)
        gcmEncrypter = gcm.encrypter()
        gcmDecrypter = gcm.decrypter()
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    // 1.150s
    func testCBCEncryption() {
        let suite = TestUtils.generateDataSuite(1000, 100000)
        measure {
            for data in suite {
                let _ = try! self.cbcEncrypter.encryptData(data, flags: nil)
            }
        }
    }

    // 0.684s
    func testGCMEncryption() {
        let suite = TestUtils.generateDataSuite(1000, 100000)
        let ad: [UInt8] = [0x11, 0x22, 0x33, 0x44]
        var flags = ad.withUnsafeBufferPointer {
            return CryptoFlags(iv: nil, ivLength: 0, ad: $0.baseAddress, adLength: ad.count)
        }
        measure {
            for data in suite {
                let _ = try! self.gcmEncrypter.encryptData(data, flags: &flags)
            }
        }
    }
}
