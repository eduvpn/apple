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
@testable import AppForce1_VPN
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

    func testConfigApiDiscoveryEnabled() {
        let actual = Config.shared.apiDiscoveryEnabled
        let expected = false

        XCTAssertEqual(actual, expected)
    }

    func testConfigAppName() {
        let actual = Config.shared.appName
        let expected = "eduVPN"

        XCTAssertEqual(actual, expected)
    }

    func testConfigClientId() {
        let actual = Config.shared.clientId
        let expected = "org.eduvpn.app.ios"

        XCTAssertEqual(actual, expected)
    }

    func testConfigDiscoveryServer() {
        let actual = Config.shared.discovery?.server
        let expected = URL(string: "https://static.eduvpn.nl")

        XCTAssertEqual(actual, expected)
    }

    func testConfigDiscoveryPathInstituteAccess() {
        let actual = Config.shared.discovery?.pathInstituteAccess
        let expected = "disco/institute_access.json"

        XCTAssertEqual(actual, expected)
    }

    func testConfigDiscoveryPathInstituteAccessSignature() {
        let actual = Config.shared.discovery?.pathInstituteAccessSignature
        let expected = "disco/institute_access.json.sig"

        XCTAssertEqual(actual, expected)
    }

    func testConfigDiscoveryPathSecureInternet() {
        let actual = Config.shared.discovery?.pathSecureInternet
        let expected = "disco/secure_internet.json"

        XCTAssertEqual(actual, expected)
    }

    func testConfigDiscoveryPathSecureInternetSignature() {
        let actual = Config.shared.discovery?.pathSecureInternetSignature
        let expected = "disco/secure_internet.json.sig"

        XCTAssertEqual(actual, expected)
    }

    func testConfigDiscoverySignaturePublicKey() {
        let actual = Config.shared.discovery?.signaturePublicKey?.base64EncodedString()
        let expected = "E5On0JTtyUVZmcWd+I/FXRm32nSq8R2ioyW7dcu/U88="

        XCTAssertEqual(actual, expected)
    }

    func testConfigPredefinedProvider() {
        let actual = Config.shared.predefinedProvider
        let expected: URL? = nil

        XCTAssertEqual(actual, expected)
    }

    func testConfigRedirectUrl() {
        let actual = Config.shared.redirectUrl
        let expected = URL(string: "org.eduvpn.app.ios:/api/callback")

        XCTAssertEqual(actual, expected)
    }

    func testConfigSupportUrl() {
        let actual = Config.shared.supportURL
        let expected = URL(string: "")

        XCTAssertEqual(actual, expected)
    }
}
