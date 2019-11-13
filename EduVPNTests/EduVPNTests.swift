//
//  EduVPNTests.swift
//  EduVPNTests
//
//  Created by Jeroen Leenarts on 29-07-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

import XCTest

#if eduVPN
@testable import eduVPN
#elseif AppForce1
@testable import AppForce1
#elseif LetsConnect
@testable import LetsConnect
#endif

class EduVPNTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testConfig() {
        let actual = Config.shared.clientId
        let expected = "org.eduvpn.app.ios"

        XCTAssertEqual(actual, expected)
    }
}
