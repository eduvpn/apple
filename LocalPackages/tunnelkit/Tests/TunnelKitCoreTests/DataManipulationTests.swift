//
//  DataManipulationTests.swift
//  TunnelKitCoreTests
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

class DataManipulationTests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testUInt() {
        let data = Data([0x22, 0xff, 0xaa, 0xbb, 0x55, 0x66])
        
        XCTAssertEqual(data.UInt16Value(from: 3), 0x55bb)
        XCTAssertEqual(data.UInt32Value(from: 2), 0x6655bbaa)
        XCTAssertEqual(data.UInt16Value(from: 4), 0x6655)
        XCTAssertEqual(data.UInt32Value(from: 0), 0xbbaaff22)
        
//        XCTAssertEqual(data.UInt16Value(from: 3), data.UInt16ValueFromPointers(from: 3))
//        XCTAssertEqual(data.UInt32Value(from: 2), data.UInt32ValueFromBuffer(from: 2))
//        XCTAssertEqual(data.UInt16Value(from: 4), data.UInt16ValueFromPointers(from: 4))
//        XCTAssertEqual(data.UInt32Value(from: 0), data.UInt32ValueFromBuffer(from: 0))
    }
    
    func testZeroingData() {
        let z1 = Z()
        z1.append(Z(Data(hex: "12345678")))
        z1.append(Z(Data(hex: "abcdef")))
        let z2 = z1.withOffset(2, count: 3) // 5678ab
        let z3 = z2.appending(Z(Data(hex: "aaddcc"))) // 5678abaaddcc
        
        XCTAssertEqual(z1.toData(), Data(hex: "12345678abcdef"))
        XCTAssertEqual(z2.toData(), Data(hex: "5678ab"))
        XCTAssertEqual(z3.toData(), Data(hex: "5678abaaddcc"))
    }
    
    func testFlatCount() {
        var v: [Data] = []
        v.append(Data(hex: "11223344"))
        v.append(Data(hex: "1122"))
        v.append(Data(hex: "1122334455"))
        v.append(Data(hex: "11223344556677"))
        v.append(Data(hex: "112233"))
        XCTAssertEqual(v.flatCount, 21)
    }
}
