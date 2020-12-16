//
//  EduVPN_Tests_iOS.swift
//  EduVPN-Tests-iOS
//
//  Created by Johan Kool on 09/12/2020.
//  Copyright © 2020 SURFNet. All rights reserved.
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
