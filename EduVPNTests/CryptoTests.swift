//
//  CryptoTests.swift
//  EduVPNTests
//
//  Created by Jeroen Leenarts on 30/11/2019.
//  Copyright © 2019 SURFNet. All rights reserved.
//

import XCTest

#if eduVPN
@testable import eduVPN
#elseif EduVPN
@testable import EduVPN
#elseif AppForce1
@testable import AppForce1_VPN
#elseif LetsConnect
@testable import LetsConnect
#endif

class CryptoTests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testEncrypt() throws {
        let input = "This is a test"
        let crypto = Crypto()
        let crypted = try crypto.encrypt(data: input.data(using: .utf8)!)
        XCTAssertNotNil(crypted)
        let decrypted = crypto.decrypt(data: crypted!)
        XCTAssertNotNil(decrypted)
        let output = String(data: decrypted!, encoding: .utf8)

        XCTAssertEqual(input, output)
    }
}
