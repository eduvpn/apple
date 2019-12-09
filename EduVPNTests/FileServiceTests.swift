//
//  FileServiceTests.swift
//  EduVPNTests
//
//  Created by Jeroen Leenarts on 19/11/2019.
//  Copyright © 2019 SURFNet. All rights reserved.
//

import XCTest

#if eduVPN
@testable import eduVPN
#elseif AppForce1
@testable import AppForce1_VPN
#elseif LetsConnect
@testable import LetsConnect
#endif

class FileServiceTests: XCTestCase {

    func testFilePathUrl() {
        guard let commonRoot = applicationSupportDirectoryUrl()?.standardizedFileURL.absoluteString else {
            XCTFail("No commonRoot.")
            return
        }

        guard let input = URL(string: "http://www.example.com//foo//bar//") else {
            XCTFail("No input.")
            return
        }

        let result = filePathUrl(from: input)?.absoluteString
        var expected = "\(commonRoot)www.example.com/foo/bar"
        if result?.last == "/" {
            expected.append("/")
        }
        XCTAssertEqual(result, expected)
    }

}
