//
//  RoutingTests.swift
//  TunnelKitCoreTests
//
//  Created by Davide De Rosa on 4/30/19.
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
import CTunnelKitCore

class RoutingTests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testEntryMatch4() {
        let entry24 = RoutingTableEntry(iPv4Network: "192.168.1.0/24", gateway: nil, networkInterface: "en0")
        print(entry24.networkMask()!)
        for i in 0x0...0xff {
            XCTAssertTrue(entry24.matchesDestination("192.168.1.\(i)"))
        }
        for i in 0x0...0xff {
            XCTAssertFalse(entry24.matchesDestination("192.168.2.\(i)"))
        }

        let entry28 = RoutingTableEntry(iPv4Network: "192.168.1.0/28", gateway: nil, networkInterface: "en0")
        print(entry28.networkMask()!)
        for i in 0x0...0xf {
            XCTAssertTrue(entry28.matchesDestination("192.168.1.\(i)"))
        }
        for i in 0x10...0x1f {
            XCTAssertFalse(entry28.matchesDestination("192.168.1.\(i)"))
        }
    }

    func testEntryMatch6() {
        let entry24 = RoutingTableEntry(iPv6Network: "abcd:efef:1234::/46", gateway: nil, networkInterface: "en0")
        for i in 0x0...0xf {
            XCTAssertTrue(entry24.matchesDestination("abcd:efef:1234::\(i)"))
        }
        for i in 0x0...0xf {
            XCTAssertFalse(entry24.matchesDestination("abcd:efef:1233::\(i)"))
        }
    }
    
    func testFindGatewayLAN4() {
        let table = RoutingTable()
        
        for entry in table.ipv4() {
            print(entry)
        }

        if let defaultGateway = table.defaultGateway4()?.gateway() {
            print("Default gateway: \(defaultGateway)")
            if let lan = table.broadestRoute4(matchingDestination: defaultGateway) {
                print("Gateway LAN: \(lan.network())/\(lan.prefix())")
            }
        }
    }

    func testFindGatewayLAN6() {
        let table = RoutingTable()
        
        for entry in table.ipv6() {
            print(entry)
        }
        
        if let defaultGateway = table.defaultGateway6()?.gateway() {
            print("Default gateway: \(defaultGateway)")
            if let lan = table.broadestRoute6(matchingDestination: defaultGateway) {
                print("Gateway LAN: \(lan.network())/\(lan.prefix())")
            }
        }
    }
    
    func testPartitioning() {
        let v4 = RoutingTableEntry(iPv4Network: "192.168.1.0/24", gateway: nil, networkInterface: "en0")
        let v4Boundary = RoutingTableEntry(iPv4Network: "192.168.1.0/31", gateway: nil, networkInterface: "en0")
        let v6 = RoutingTableEntry(iPv6Network: "abcd:efef:120::/46", gateway: nil, networkInterface: "en0")
        let v6Boundary = RoutingTableEntry(iPv6Network: "abcd:efef:120::/127", gateway: nil, networkInterface: "en0")
        
        guard let v4parts = v4.partitioned() else {
            fatalError()
        }
        let v4parts1 = v4parts[0]
        let v4parts2 = v4parts[1]
        XCTAssertEqual(v4parts1.network(), "192.168.1.0")
        XCTAssertEqual(v4parts1.prefix(), 25)
        XCTAssertEqual(v4parts2.network(), "192.168.1.128")
        XCTAssertEqual(v4parts2.prefix(), 25)

        guard let v6parts = v6.partitioned() else {
            fatalError()
        }
        let v6parts1 = v6parts[0]
        let v6parts2 = v6parts[1]
        XCTAssertEqual(v6parts1.network(), "abcd:efef:120::")
        XCTAssertEqual(v6parts1.prefix(), 47)
        XCTAssertEqual(v6parts2.network(), "abcd:efef:122::")
        XCTAssertEqual(v6parts2.prefix(), 47)

        guard let v4BoundaryParts = v4Boundary.partitioned() else {
            fatalError()
        }
        let v4BoundaryParts1 = v4BoundaryParts[0]
        let v4BoundaryParts2 = v4BoundaryParts[1]
        XCTAssertEqual(v4BoundaryParts1.network(), "192.168.1.0")
        XCTAssertEqual(v4BoundaryParts1.prefix(), 32)
        XCTAssertEqual(v4BoundaryParts2.network(), "192.168.1.1")
        XCTAssertEqual(v4BoundaryParts2.prefix(), 32)

        guard let v6BoundaryParts = v6Boundary.partitioned() else {
            fatalError()
        }
        let v6BoundaryParts1 = v6BoundaryParts[0]
        let v6BoundaryParts2 = v6BoundaryParts[1]
        XCTAssertEqual(v6BoundaryParts1.network(), "abcd:efef:120::")
        XCTAssertEqual(v6BoundaryParts1.prefix(), 128)
        XCTAssertEqual(v6BoundaryParts2.network(), "abcd:efef:120::1")
        XCTAssertEqual(v6BoundaryParts2.prefix(), 128)
    }
}
