//
//  AppExtensionTests.swift
//  TunnelKitOpenVPNTests
//
//  Created by Davide De Rosa on 10/23/17.
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
import NetworkExtension
import TunnelKitCore
import TunnelKitOpenVPNCore
import TunnelKitAppExtension
@testable import TunnelKitOpenVPNAppExtension
import TunnelKitManager
import TunnelKitOpenVPNManager

class AppExtensionTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testConfiguration() {
        var builder: OpenVPNProvider.ConfigurationBuilder!
        var cfg: OpenVPNProvider.Configuration!

        let identifier = "com.example.Provider"
        let appGroup = "group.com.algoritmico.TunnelKit"
        let hostname = "example.com"
        let context = "foobar"
        let credentials = OpenVPN.Credentials("foo", "bar")

        var sessionBuilder = OpenVPN.ConfigurationBuilder()
        sessionBuilder.ca = OpenVPN.CryptoContainer(pem: "abcdef")
        sessionBuilder.cipher = .aes128cbc
        sessionBuilder.digest = .sha256
        sessionBuilder.hostname = hostname
        sessionBuilder.endpointProtocols = []
        sessionBuilder.mtu = 1230
        builder = OpenVPNProvider.ConfigurationBuilder(sessionConfiguration: sessionBuilder.build())
        XCTAssertNotNil(builder)

        cfg = builder.build()

        let proto = try? cfg.generatedTunnelProtocol(
            withBundleIdentifier: identifier,
            appGroup: appGroup,
            context: context,
            credentials: credentials
        )
        XCTAssertNotNil(proto)
        
        XCTAssertEqual(proto?.providerBundleIdentifier, identifier)
        XCTAssertEqual(proto?.serverAddress, hostname)
        XCTAssertEqual(proto?.username, credentials.username)
        XCTAssertEqual(proto?.passwordReference, try? Keychain(group: appGroup).passwordReference(for: credentials.username, context: context))

        guard let pc = proto?.providerConfiguration else {
            return
        }
        print("\(pc)")

        let pcSession = pc["sessionConfiguration"] as? [String: Any]
        XCTAssertEqual(pc["appGroup"] as? String, appGroup)
        XCTAssertEqual(pc["shouldDebug"] as? Bool, cfg.shouldDebug)
        XCTAssertEqual(pcSession?["cipher"] as? String, cfg.sessionConfiguration.cipher?.rawValue)
        XCTAssertEqual(pcSession?["digest"] as? String, cfg.sessionConfiguration.digest?.rawValue)
        XCTAssertEqual(pcSession?["ca"] as? String, cfg.sessionConfiguration.ca?.pem)
        XCTAssertEqual(pcSession?["mtu"] as? Int, cfg.sessionConfiguration.mtu)
        XCTAssertEqual(pcSession?["renegotiatesAfter"] as? TimeInterval, cfg.sessionConfiguration.renegotiatesAfter)
    }
    
    func testDNSResolver() {
        let exp = expectation(description: "DNS")
        DNSResolver.resolve("www.google.com", timeout: 1000, queue: .main) { (addrs, error) in
            defer {
                exp.fulfill()
            }
            guard let addrs = addrs else {
                print("Can't resolve")
                return
            }
            print("\(addrs)")
        }
        waitForExpectations(timeout: 5.0, handler: nil)
    }
    
    func testDNSAddressConversion() {
        let testStrings = [
            "0.0.0.0",
            "1.2.3.4",
            "111.222.333.444",
            "1.0.3.255",
            "1.2.255.4",
            "1.2.3.0",
            "255.255.255.255"
        ]
        for expString in testStrings {
            guard let number = DNSResolver.ipv4(fromString: expString) else {
                XCTAssertEqual(expString, "111.222.333.444")
                continue
            }
            let string = DNSResolver.string(fromIPv4: number)
            XCTAssertEqual(string, expString)
        }
    }

    func testEndpointCycling() {
        CoreConfiguration.masksPrivateData = false

        var builder1 = OpenVPN.ConfigurationBuilder()
        builder1.hostname = "italy.privateinternetaccess.com"
        builder1.endpointProtocols = [
            EndpointProtocol(.tcp6, 2222),
            EndpointProtocol(.udp, 1111),
            EndpointProtocol(.udp4, 3333)
        ]
        var builder2 = OpenVPNProvider.ConfigurationBuilder(sessionConfiguration: builder1.build())
        builder2.prefersResolvedAddresses = true
        builder2.resolvedAddresses = [
            "82.102.21.218",
            "82.102.21.214",
            "82.102.21.213",
        ]
        let strategy = ConnectionStrategy(configuration: builder2.build())
        
        let expected = [
            "82.102.21.218:UDP:1111",
            "82.102.21.218:UDP4:3333",
            "82.102.21.214:UDP:1111",
            "82.102.21.214:UDP4:3333",
            "82.102.21.213:UDP:1111",
            "82.102.21.213:UDP4:3333",
        ]
        var i = 0
        while strategy.hasEndpoint() {
            let endpoint = strategy.currentEndpoint()
            print("\(endpoint)")
            XCTAssertEqual(endpoint.description, expected[i])
            i += 1
            strategy.tryNextEndpoint()
        }
    }

//    func testEndpointCycling4() {
//        CoreConfiguration.masksPrivateData = false
//
//        var builder = OpenVPN.ConfigurationBuilder()
//        builder.hostname = "italy.privateinternetaccess.com"
//        builder.endpointProtocols = [
//            EndpointProtocol(.tcp4, 2222),
//        ]
//        let strategy = ConnectionStrategy(
//            configuration: builder.build(),
//            resolvedRecords: [
//                DNSRecord(address: "111:bbbb:ffff::eeee", isIPv6: true),
//                DNSRecord(address: "11.22.33.44", isIPv6: false),
//            ]
//        )
//
//        let expected = [
//            "11.22.33.44:TCP4:2222"
//        ]
//        var i = 0
//        while strategy.hasEndpoint() {
//            let endpoint = strategy.currentEndpoint()
//            print("\(endpoint)")
//            XCTAssertEqual(endpoint.description, expected[i])
//            i += 1
//            strategy.tryNextEndpoint()
//        }
//    }
//
//    func testEndpointCycling6() {
//        CoreConfiguration.masksPrivateData = false
//
//        var builder = OpenVPN.ConfigurationBuilder()
//        builder.hostname = "italy.privateinternetaccess.com"
//        builder.endpointProtocols = [
//            EndpointProtocol(.udp6, 2222),
//        ]
//        let strategy = ConnectionStrategy(
//            configuration: builder.build(),
//            resolvedRecords: [
//                DNSRecord(address: "111:bbbb:ffff::eeee", isIPv6: true),
//                DNSRecord(address: "11.22.33.44", isIPv6: false),
//            ]
//        )
//
//        let expected = [
//            "111:bbbb:ffff::eeee:UDP6:2222"
//        ]
//        var i = 0
//        while strategy.hasEndpoint() {
//            let endpoint = strategy.currentEndpoint()
//            print("\(endpoint)")
//            XCTAssertEqual(endpoint.description, expected[i])
//            i += 1
//            strategy.tryNextEndpoint()
//        }
//    }
}
