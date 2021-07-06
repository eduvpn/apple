//
//  EduVPN_Tests_iOS.swift
//  EduVPN-Tests-iOS
//
//  Copyright © 2020-2021 The Commons Conservancy. All rights reserved.
//

import XCTest

@testable import eduVPN

class EduVPNTestsiOS: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testConfig() {
        let actual = Config.shared.clientId
        let expected = "org.eduvpn.app.ios"

        XCTAssertEqual(actual, expected)
    }

}
