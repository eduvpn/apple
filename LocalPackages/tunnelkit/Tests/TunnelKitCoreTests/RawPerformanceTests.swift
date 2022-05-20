//
//  RawPerformanceTests.swift
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

import Foundation

import XCTest
@testable import TunnelKitCore

class RawPerformanceTests: XCTestCase {
    
    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    // 0.434s
    func testUInt16FromBuffer() {
        let data = Data([0x22, 0xff, 0xaa, 0xbb, 0x55, 0x66])
        
        measure {
            for _ in 0..<1000000 {
                let _ = data.UInt16Value(from: 3)
            }
        }
    }
    
//    // 0.463s
//    func testUInt16FromPointers() {
//        let data = Data([0x22, 0xff, 0xaa, 0xbb, 0x55, 0x66])
//
//        measure {
//            for _ in 0..<1000000 {
//                let _ = data.UInt16ValueFromPointers(from: 3)
//            }
//        }
//    }
//
//    // 0.863s
//    func testUInt32FromBuffer() {
//        let data = Data([0x22, 0xff, 0xaa, 0xbb, 0x55, 0x66])
//
//        measure {
//            for _ in 0..<1000000 {
//                let _ = data.UInt32ValueFromBuffer(from: 1)
//            }
//        }
//    }
    
    // 0.469s
    func testUInt32FromPointers() {
        let data = Data([0x22, 0xff, 0xaa, 0xbb, 0x55, 0x66])
        
        measure {
            for _ in 0..<1000000 {
                let _ = data.UInt32Value(from: 1)
            }
        }
    }
    
//    // 0.071s
//    func testRandomUInt32FromBuffer() {
//        measure {
//            for _ in 0..<10000 {
//                let _ = try! SecureRandom.uint32FromBuffer()
//            }
//        }
//    }
    
    // 0.063s
    func testRandomUInt32FromPointers() {
        measure {
            for _ in 0..<10000 {
                let _ = try! SecureRandom.uint32()
            }
        }
    }

    // 0.215s
    func testMyPacketHeader() {
        let suite = TestUtils.generateDataSuite(1000, 200000)
        measure {
            for data in suite {
                CFSwapInt32BigToHost(data.UInt32Value(from: 0))
            }
        }
    }

    // 0.146s
    func testStevePacketHeader() {
        let suite = TestUtils.generateDataSuite(1000, 200000)
        measure {
            for data in suite {
//                let _ = UInt32(bigEndian: data.subdata(in: 0..<4).withUnsafeBytes { $0.pointee })
                let _ = data.networkUInt32Value(from: 0)
            }
        }
    }

    // 0.060s
    func testDataSubdata() {
        let suite = TestUtils.generateDataSuite(1000, 100000)
        measure {
            for data in suite {
                let _ = data.subdata(in: 5..<data.count)
            }
        }
    }

    // 0.118s
    func testDataRemoveSubrange() {
        let suite = TestUtils.generateDataSuite(1000, 100000)
        measure {
            for var data in suite {
                data.removeSubrange(0..<5)
            }
        }
    }
}
