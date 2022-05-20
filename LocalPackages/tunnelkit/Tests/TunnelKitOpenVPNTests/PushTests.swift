//
//  PushTests.swift
//  TunnelKitOpenVPNTests
//
//  Created by Davide De Rosa on 8/24/18.
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
@testable import TunnelKitOpenVPNCore
@testable import TunnelKitOpenVPNProtocol
@testable import TunnelKitOpenVPNAppExtension

private extension OpenVPN.PushReply {
    func debug() {
        print("Compression framing: \(options.compressionFraming?.description ?? "disabled")")
        print("Compression algorithm: \(options.compressionAlgorithm?.description ?? "disabled")")
        print("IPv4: \(options.ipv4?.description ?? "none")")
        print("IPv6: \(options.ipv6?.description ?? "none")")
        print("DNS: \(options.dnsServers?.description ?? "none")")
    }
}

class PushTests: XCTestCase {
    
    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testNet30() {
        let msg = "PUSH_REPLY,redirect-gateway def1,dhcp-option DNS 209.222.18.222,dhcp-option DNS 209.222.18.218,ping 10,comp-lzo no,route 10.5.10.1,topology net30,ifconfig 10.5.10.6 10.5.10.5,auth-token AUkQf/b3nj3L+CH4RJPP0Vuq8/gpntr7uPqzjQhncig="
        let reply = try! OpenVPN.PushReply(message: msg)!
        reply.debug()

        XCTAssertEqual(reply.options.ipv4?.address, "10.5.10.6")
        XCTAssertEqual(reply.options.ipv4?.addressMask, "255.255.255.255")
        XCTAssertEqual(reply.options.ipv4?.defaultGateway, "10.5.10.5")
        XCTAssertEqual(reply.options.dnsServers, ["209.222.18.222", "209.222.18.218"])
    }
    
    func testSubnet() {
        let msg = "PUSH_REPLY,dhcp-option DNS 8.8.8.8,dhcp-option DNS 4.4.4.4,route-gateway 10.8.0.1,topology subnet,ping 10,ping-restart 120,ifconfig 10.8.0.2 255.255.255.0,peer-id 0"
        let reply = try! OpenVPN.PushReply(message: msg)!
        reply.debug()
        
        XCTAssertEqual(reply.options.ipv4?.address, "10.8.0.2")
        XCTAssertEqual(reply.options.ipv4?.addressMask, "255.255.255.0")
        XCTAssertEqual(reply.options.ipv4?.defaultGateway, "10.8.0.1")
        XCTAssertEqual(reply.options.dnsServers, ["8.8.8.8", "4.4.4.4"])
    }
    
    func testRoute() {
        let msg = "PUSH_REPLY,dhcp-option DNS 8.8.8.8,dhcp-option DNS 4.4.4.4,route-gateway 10.8.0.1,route 192.168.0.0 255.255.255.0 10.8.0.12,topology subnet,ping 10,ping-restart 120,ifconfig 10.8.0.2 255.255.255.0,peer-id 0"
        let reply = try! OpenVPN.PushReply(message: msg)!
        reply.debug()
        
        let route = reply.options.ipv4!.routes.first!
        
        XCTAssertEqual(route.destination, "192.168.0.0")
        XCTAssertEqual(route.mask, "255.255.255.0")
        XCTAssertEqual(route.gateway, "10.8.0.12")
    }

    func testIPv6() {
        let msg = "PUSH_REPLY,dhcp-option DNS6 2001:4860:4860::8888,dhcp-option DNS6 2001:4860:4860::8844,tun-ipv6,route-gateway 10.8.0.1,topology subnet,ping 10,ping-restart 120,ifconfig-ipv6 fe80::601:30ff:feb7:ec01/64 fe80::601:30ff:feb7:dc02,ifconfig 10.8.0.2 255.255.255.0,peer-id 0"
        let reply = try! OpenVPN.PushReply(message: msg)!
        reply.debug()
        
        XCTAssertEqual(reply.options.ipv4?.address, "10.8.0.2")
        XCTAssertEqual(reply.options.ipv4?.addressMask, "255.255.255.0")
        XCTAssertEqual(reply.options.ipv4?.defaultGateway, "10.8.0.1")
        XCTAssertEqual(reply.options.ipv6?.address, "fe80::601:30ff:feb7:ec01")
        XCTAssertEqual(reply.options.ipv6?.addressPrefixLength, 64)
        XCTAssertEqual(reply.options.ipv6?.defaultGateway, "fe80::601:30ff:feb7:dc02")
        XCTAssertEqual(reply.options.dnsServers, ["2001:4860:4860::8888", "2001:4860:4860::8844"])
    }
    
    func testCompressionFraming() {
        let msg = "PUSH_REPLY,dhcp-option DNS 8.8.8.8,dhcp-option DNS 4.4.4.4,comp-lzo no,route 10.8.0.1,topology net30,ping 10,ping-restart 120,ifconfig 10.8.0.6 10.8.0.5,peer-id 0,cipher AES-256-CBC"
        let reply = try! OpenVPN.PushReply(message: msg)!
        reply.debug()
        
        XCTAssertEqual(reply.options.compressionFraming, .compLZO)
    }
    
    func testCompression() {
        let msg = "PUSH_REPLY,dhcp-option DNS 8.8.8.8,dhcp-option DNS 4.4.4.4,route 10.8.0.1,topology net30,ping 10,ping-restart 120,ifconfig 10.8.0.6 10.8.0.5,peer-id 0,cipher AES-256-CBC"
        var reply: OpenVPN.PushReply
        
        reply = try! OpenVPN.PushReply(message: msg.appending(",comp-lzo no"))!
        reply.debug()
        XCTAssertEqual(reply.options.compressionFraming, .compLZO)
        XCTAssertEqual(reply.options.compressionAlgorithm, .disabled)

        reply = try! OpenVPN.PushReply(message: msg.appending(",comp-lzo"))!
        reply.debug()
        XCTAssertEqual(reply.options.compressionFraming, .compLZO)
        XCTAssertEqual(reply.options.compressionAlgorithm, .LZO)

        reply = try! OpenVPN.PushReply(message: msg.appending(",comp-lzo yes"))!
        reply.debug()
        XCTAssertEqual(reply.options.compressionFraming, .compLZO)
        XCTAssertEqual(reply.options.compressionAlgorithm, .LZO)

        reply = try! OpenVPN.PushReply(message: msg.appending(",compress"))!
        reply.debug()
        XCTAssertEqual(reply.options.compressionFraming, .compress)
        XCTAssertEqual(reply.options.compressionAlgorithm, .disabled)

        reply = try! OpenVPN.PushReply(message: msg.appending(",compress lz4"))!
        reply.debug()
        XCTAssertEqual(reply.options.compressionFraming, .compress)
        XCTAssertEqual(reply.options.compressionAlgorithm, .other)
    }
    
    func testNCP() {
        let msg = "PUSH_REPLY,dhcp-option DNS 8.8.8.8,dhcp-option DNS 4.4.4.4,comp-lzo no,route 10.8.0.1,topology net30,ping 10,ping-restart 120,ifconfig 10.8.0.6 10.8.0.5,peer-id 0,cipher AES-256-GCM"
        let reply = try! OpenVPN.PushReply(message: msg)!
        reply.debug()

        XCTAssertEqual(reply.options.cipher, .aes256gcm)
    }

    func testNCPTrailing() {
        let msg = "PUSH_REPLY,dhcp-option DNS 8.8.8.8,dhcp-option DNS 4.4.4.4,comp-lzo no,route 10.8.0.1,topology net30,ping 10,ping-restart 120,ifconfig 10.8.0.18 10.8.0.17,peer-id 3,cipher AES-256-GCM,auth-token"
        let reply = try! OpenVPN.PushReply(message: msg)!
        reply.debug()
        
        XCTAssertEqual(reply.options.cipher, .aes256gcm)
    }
    
    func testPing() {
        let msg = "PUSH_REPLY,route 192.168.1.0 255.255.255.0,route 10.0.2.0 255.255.255.0,dhcp-option DNS 192.168.1.99,dhcp-option DNS 176.103.130.130,route 10.0.2.1,topology net30,ping 10,ping-restart 60,ifconfig 10.0.2.14 10.0.2.13"
        let reply = try! OpenVPN.PushReply(message: msg)!
        reply.debug()
        
        XCTAssertEqual(reply.options.keepAliveInterval, 10)
    }
    
    func testPingRestart() {
        let msg = "PUSH_REPLY,route 192.168.1.0 255.255.255.0,route 10.0.2.0 255.255.255.0,dhcp-option DNS 192.168.1.99,dhcp-option DNS 176.103.130.130,route 10.0.2.1,topology net30,ping 10,ping-restart 60,ifconfig 10.0.2.14 10.0.2.13"
        let reply = try! OpenVPN.PushReply(message: msg)!
        reply.debug()
        
        XCTAssertEqual(reply.options.keepAliveTimeout, 60)
    }
    
    func testProvost() {
        let msg = "PUSH_REPLY,route 87.233.192.218,route 87.233.192.219,route 87.233.192.220,route 87.248.186.252,route 92.241.171.245,route 103.246.200.0 255.255.252.0,route 109.239.140.0 255.255.255.0,route 128.199.0.0 255.255.0.0,route 13.125.0.0 255.255.0.0,route 13.230.0.0 255.254.0.0,route 13.56.0.0 255.252.0.0,route 149.154.160.0 255.255.252.0,route 149.154.164.0 255.255.252.0,route 149.154.168.0 255.255.252.0,route 149.154.172.0 255.255.252.0,route 159.122.128.0 255.255.192.0,route 159.203.0.0 255.255.0.0,route 159.65.0.0 255.255.0.0,route 159.89.0.0 255.255.0.0,route 165.227.0.0 255.255.0.0,route 167.99.0.0 255.255.0.0,route 174.138.0.0 255.255.128.0,route 176.67.169.0 255.255.255.0,route 178.239.88.0 255.255.248.0,route 178.63.0.0 255.255.0.0,route 18.130.0.0 255.255.0.0,route 18.144.0.0 255.255.0.0,route 18.184.0.0 255.254.0.0,route 18.194.0.0 255.254.0.0,route 18.196.0.0 255.254.0.0,route 18.204.0.0 255.252.0.0,push-continuation 2"
        let reply = try? OpenVPN.PushReply(message: msg)!
        reply?.debug()
    }
    
    func testPeerInfo() {
        let peerInfo = CoreConfiguration.OpenVPN.peerInfo()
        print(peerInfo)
    }
}
