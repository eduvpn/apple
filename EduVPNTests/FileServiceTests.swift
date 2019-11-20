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
@testable import AppForce1
#elseif LetsConnect
@testable import LetsConnect
#endif

class FileServiceTests: XCTestCase {

    func testFilePathUrl() {
        let commonRoot = applicationSupportDirectoryUrl()!.standardizedFileURL.absoluteString

        let result = filePathUrl(from: URL(string: "http://www.example.com//foo//bar//")!)?.absoluteString
        let expected = "\(commonRoot)www.example.com/foo/bar/"
        XCTAssertEqual(result, expected)
    }

}
