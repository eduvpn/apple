//
//  LinkTests.swift
//  TunnelKitOpenVPNTests
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
@testable import CTunnelKitCore

class LinkTests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    // UDP
    
    func testUnreliableControlQueue() {
        let seq1 = [0, 5, 2, 1, 4, 3]
        let seq2 = [5, 2, 1, 9, 4, 3, 0, 8, 7, 10, 4, 3, 5, 6]
        let seq3 = [5, 2, 11, 1, 2, 9, 4, 5, 5, 3, 8, 0, 6, 8, 2, 7, 10, 4, 3, 5, 6]
        
        for seq in [seq1, seq2, seq3] {
            XCTAssertEqual(TestUtils.uniqArray(seq.sorted()), handleControlSequence(seq))
        }
    }
    
    // TCP
    
//    private func testPacketStream() {
//        var bytes: [UInt8] = []
//        var until: Int
//        var packets: [Data]
//
//        bytes.append(contentsOf: [0x00, 0x04])
//        bytes.append(contentsOf: [0x10, 0x20, 0x30, 0x40])
//        bytes.append(contentsOf: [0x00, 0x07])
//        bytes.append(contentsOf: [0x10, 0x20, 0x30, 0x40, 0x50, 0x66, 0x77])
//        bytes.append(contentsOf: [0x00, 0x01])
//        bytes.append(contentsOf: [0xff])
//        bytes.append(contentsOf: [0x00, 0x03])
//        bytes.append(contentsOf: [0xaa])
//        XCTAssertEqual(bytes.count, 21)
//
//        (until, packets) = PacketStream.packets(from: Data(bytes))
//        XCTAssertEqual(until, 18)
//        XCTAssertEqual(packets.count, 3)
//
//        bytes.append(contentsOf: [0xbb, 0xcc])
//        (until, packets) = PacketStream.packets(from: Data(bytes))
//        XCTAssertEqual(until, 23)
//        XCTAssertEqual(packets.count, 4)
//
//        bytes.append(contentsOf: [0x00, 0x05])
//        (until, packets) = PacketStream.packets(from: Data(bytes))
//        XCTAssertEqual(until, 23)
//        XCTAssertEqual(packets.count, 4)
//
//        bytes.append(contentsOf: [0x11, 0x22, 0x33, 0x44])
//        (until, packets) = PacketStream.packets(from: Data(bytes))
//        XCTAssertEqual(until, 23)
//        XCTAssertEqual(packets.count, 4)
//
//        bytes.append(contentsOf: [0x55])
//        (until, packets) = PacketStream.packets(from: Data(bytes))
//        XCTAssertEqual(until, 30)
//        XCTAssertEqual(packets.count, 5)
//
//        //
//
//        bytes.removeSubrange(0..<until)
//        XCTAssertEqual(bytes.count, 0)
//
//        bytes.append(contentsOf: [0x00, 0x04])
//        bytes.append(contentsOf: [0x10, 0x20])
//        (until, packets) = PacketStream.packets(from: Data(bytes))
//        XCTAssertEqual(until, 0)
//        XCTAssertEqual(packets.count, 0)
//        bytes.removeSubrange(0..<until)
//        XCTAssertEqual(bytes.count, 4)
//
//        bytes.append(contentsOf: [0x30, 0x40])
//        bytes.append(contentsOf: [0x00, 0x07])
//        bytes.append(contentsOf: [0x10, 0x20, 0x30, 0x40])
//        (until, packets) = PacketStream.packets(from: Data(bytes))
//        XCTAssertEqual(until, 6)
//        XCTAssertEqual(packets.count, 1)
//        bytes.removeSubrange(0..<until)
//        XCTAssertEqual(bytes.count, 6)
//
//        bytes.append(contentsOf: [0x50, 0x66, 0x77])
//        bytes.append(contentsOf: [0x00, 0x01])
//        bytes.append(contentsOf: [0xff])
//        bytes.append(contentsOf: [0x00, 0x03])
//        bytes.append(contentsOf: [0xaa])
//        (until, packets) = PacketStream.packets(from: Data(bytes))
//        XCTAssertEqual(until, 12)
//        XCTAssertEqual(packets.count, 2)
//        bytes.removeSubrange(0..<until)
//        XCTAssertEqual(bytes.count, 3)
//
//        bytes.append(contentsOf: [0xbb, 0xcc])
//        (until, packets) = PacketStream.packets(from: Data(bytes))
//        XCTAssertEqual(until, 5)
//        XCTAssertEqual(packets.count, 1)
//        bytes.removeSubrange(0..<until)
//        XCTAssertEqual(bytes.count, 0)
//    }

    // helpers

    private func handleControlSequence(_ seq: [Int]) -> [Int] {
        var q = [Int]()
        var id = 0
        var hdl = [Int]()
        for p in seq {
            enqueueControl(&q, &id, p) {
                hdl.append($0)
            }
            print()
        }
        return hdl
    }
    
    private func enqueueControl(_ q: inout [Int], _ id: inout Int, _ p: Int, _ h: (Int) -> Void) {
        q.append(p)
        q.sort { (p1, p2) -> Bool in
            return (p1 < p2)
        }
        
        print("q = \(q)")
        print("id = \(id)")
        for p in q {
            print("test(\(p))")
            if (p < id) {
                q.removeFirst()
                continue
            }
            if (p != id) {
                return
            }
            
            h(p)
            print("handle(\(p))")
            id += 1
            q.removeFirst()
        }
    }
}
