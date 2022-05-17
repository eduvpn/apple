//
//  CompressionTests.swift
//  TunnelKitLZOTests
//
//  Created by Davide De Rosa on 3/18/19.
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

import XCTest
@testable import TunnelKitCore
import CTunnelKitCore
import TunnelKitLZO

class CompressionTests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
//        print("LZO version: \(LZO.versionString())")
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testSymmetric() {
        XCTAssertTrue(LZOFactory.isSupported());
        let lzo = LZOFactory.create()
        let src = Data([UInt8](repeating: 6, count: 100))
        guard let dst = try? lzo.compressedData(with: src) else {
            XCTFail("Uncompressible data")
            return
        }
        guard let dstDecompressed = try? lzo.decompressedData(with: dst) else {
            XCTFail("Unable to decompress data")
            return
        }
        print("BEFORE: \(src)")
        print("AFTER : \(dstDecompressed)")
        XCTAssertEqual(src, dstDecompressed)
    }
}
