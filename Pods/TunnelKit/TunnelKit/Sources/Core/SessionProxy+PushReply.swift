//
//  SessionProxy+PushReply.swift
//  TunnelKit
//
//  Created by Davide De Rosa on 7/25/18.
//  Copyright (c) 2018 Davide De Rosa. All rights reserved.
//
//  https://github.com/keeshux
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
//

import Foundation

/// Encapsulates the IPv4 settings for the tunnel.
public struct IPv4Settings: CustomStringConvertible {

    /// Represents an IPv4 route in the routing table.
    public struct Route: CustomStringConvertible {
        
        /// The destination host or subnet.
        public let destination: String
        
        /// The address mask.
        public let mask: String
        
        /// The address of the gateway (uses default gateway if not set).
        public let gateway: String?
        
        fileprivate init(_ destination: String, _ mask: String?, _ gateway: String?) {
            self.destination = destination
            self.mask = mask ?? "255.255.255.255"
            self.gateway = gateway
        }

        // MARK: CustomStringConvertible
        
        /// :nodoc:
        public var description: String {
            return "{\(destination.maskedDescription)/\(mask) \(gateway?.maskedDescription ?? "default")}"
        }
    }

    /// The address.
    let address: String
    
    /// The address mask.
    let addressMask: String
    
    /// The address of the default gateway.
    let defaultGateway: String

    /// The additional routes.
    let routes: [Route]

    // MARK: CustomStringConvertible

    /// :nodoc:
    public var description: String {
        return "addr \(address.maskedDescription) netmask \(addressMask) gw \(defaultGateway.maskedDescription) routes \(routes.map { $0.maskedDescription })"
    }
}

/// Encapsulates the IPv6 settings for the tunnel.
public struct IPv6Settings: CustomStringConvertible {

    /// Represents an IPv6 route in the routing table.
    public struct Route: CustomStringConvertible {
        
        /// The destination host or subnet.
        public let destination: String
        
        /// The address prefix length.
        public let prefixLength: UInt8
        
        /// The address of the gateway (uses default gateway if not set).
        public let gateway: String?
        
        fileprivate init(_ destination: String, _ prefixLength: UInt8?, _ gateway: String?) {
            self.destination = destination
            self.prefixLength = prefixLength ?? 3
            self.gateway = gateway
        }

        // MARK: CustomStringConvertible
        
        /// :nodoc:
        public var description: String {
            return "{\(destination.maskedDescription)/\(prefixLength) \(gateway?.maskedDescription ?? "default")}"
        }
    }

    /// The address.
    public let address: String
    
    /// The address prefix length.
    public let addressPrefixLength: UInt8
    
    /// The address of the default gateway.
    public let defaultGateway: String
    
    /// The additional routes.
    public let routes: [Route]

    // MARK: CustomStringConvertible
    
    /// :nodoc:
    public var description: String {
        return "addr \(address.maskedDescription)/\(addressPrefixLength) gw \(defaultGateway.maskedDescription) routes \(routes.map { $0.maskedDescription })"
    }
}

/// Groups the parsed reply of a successfully started session.
public protocol SessionReply {

    /// The IPv4 settings.
    var ipv4: IPv4Settings? { get }
    
    /// The IPv6 settings.
    var ipv6: IPv6Settings? { get }
    
    /// The DNS servers set up for this session.
    var dnsServers: [String] { get }
    
    /// The optional compression framing.
    var compressionFraming: SessionProxy.CompressionFraming? { get }
    
    /// True if uses compression.
    var usesCompression: Bool { get }
    
    /// The optional keep-alive interval.
    var ping: Int? { get }

    /// The optional authentication token.
    var authToken: String? { get }
    
    /// The optional 24-bit peer-id.
    var peerId: UInt32? { get }

    /// The negotiated cipher if any (NCP).
    var cipher: SessionProxy.Cipher? { get }
}

extension SessionProxy {

    // XXX: parsing is very optimistic
    
    struct PushReply: SessionReply, CustomStringConvertible {
        private enum Topology: String {
            case net30
            
            case p2p
            
            case subnet
        }
        
        private struct Regex {
            static let prefix = "PUSH_REPLY,"
            
            static let topology = NSRegularExpression("topology (net30|p2p|subnet)")
            
            static let ifconfig = NSRegularExpression("ifconfig [\\d\\.]+ [\\d\\.]+")
            
            static let ifconfig6 = NSRegularExpression("ifconfig-ipv6 [\\da-fA-F:]+/\\d+ [\\da-fA-F:]+")
            
            static let gateway = NSRegularExpression("route-gateway [\\d\\.]+")
            
            static let route = NSRegularExpression("route [\\d\\.]+( [\\d\\.]+){0,2}")
            
            static let route6 = NSRegularExpression("route-ipv6 [\\da-fA-F:]+/\\d+( [\\da-fA-F:]+){0,2}")
            
            static let dns = NSRegularExpression("dhcp-option DNS6? [\\d\\.a-fA-F:]+")
            
            static let comp = NSRegularExpression("comp(ress|-lzo)[ \\w]*")
            
            static let ping = NSRegularExpression("ping \\d+")
            
            static let authToken = NSRegularExpression("auth-token [a-zA-Z0-9/=+]+")
            
            static let peerId = NSRegularExpression("peer-id [0-9]+")
            
            static let cipher = NSRegularExpression("cipher [^,\\s]+")
        }
        
        private let original: String

        let ipv4: IPv4Settings?
        
        let ipv6: IPv6Settings?
        
        let dnsServers: [String]
        
        let compressionFraming: SessionProxy.CompressionFraming?
        
        let usesCompression: Bool

        let ping: Int?
        
        let authToken: String?
        
        let peerId: UInt32?
        
        let cipher: SessionProxy.Cipher?
        
        init?(message: String) throws {
            guard message.hasPrefix(Regex.prefix) else {
                return nil
            }
            let prefixOffset = message.index(message.startIndex, offsetBy: Regex.prefix.count)
            original = String(message[prefixOffset..<message.endIndex])

            var optTopologyArguments: [String]?
            var optIfconfig4Arguments: [String]?
            var optGateway4Arguments: [String]?
            let address4: String
            let addressMask4: String
            let defaultGateway4: String
            var routes4: [IPv4Settings.Route] = []

            var optIfconfig6Arguments: [String]?

            var dnsServers: [String] = []
            var compressionFraming: SessionProxy.CompressionFraming?
            var usesCompression = false
            var ping: Int?
            var authToken: String?
            var peerId: UInt32?
            var cipher: SessionProxy.Cipher?
            
            // MARK: Routing (IPv4)

            Regex.topology.enumerateArguments(in: message) {
                optTopologyArguments = $0
            }
            guard let topologyArguments = optTopologyArguments, topologyArguments.count == 1 else {
                throw SessionError.malformedPushReply
            }

            // assumes "topology" to be always pushed to clients, even when not explicitly set (defaults to net30)
            guard let topology = Topology(rawValue: topologyArguments[0]) else {
                fatalError("Bad topology regexp, accepted unrecognized value: \(topologyArguments[0])")
            }

            Regex.ifconfig.enumerateArguments(in: message) {
                optIfconfig4Arguments = $0
            }
            guard let ifconfig4Arguments = optIfconfig4Arguments, ifconfig4Arguments.count == 2 else {
                throw SessionError.malformedPushReply
            }
            
            Regex.gateway.enumerateArguments(in: message) {
                optGateway4Arguments = $0
            }
            
            //
            // excerpts from OpenVPN manpage
            //
            // "--ifconfig l rn":
            //
            // Set  TUN/TAP  adapter parameters.  l is the IP address of the local VPN endpoint.  For TUN devices in point-to-point mode, rn is the IP address of
            // the remote VPN endpoint.  For TAP devices, or TUN devices used with --topology subnet, rn is the subnet mask of the virtual network segment  which
            // is being created or connected to.
            //
            // "--topology mode":
            //
            // Note: Using --topology subnet changes the interpretation of the arguments of --ifconfig to mean "address netmask", no longer "local remote".
            //
            switch topology {
            case .subnet:
                
                // default gateway required when topology is subnet
                guard let gateway4Arguments = optGateway4Arguments, gateway4Arguments.count == 1 else {
                    throw SessionError.malformedPushReply
                }
                address4 = ifconfig4Arguments[0]
                addressMask4 = ifconfig4Arguments[1]
                defaultGateway4 = gateway4Arguments[0]
                
            default:
                address4 = ifconfig4Arguments[0]
                addressMask4 = "255.255.255.255"
                defaultGateway4 = ifconfig4Arguments[1]
            }

            Regex.route.enumerateArguments(in: message) {
                let routeEntryArguments = $0
                
                let address = routeEntryArguments[0]
                let mask: String?
                let gateway: String?
                if routeEntryArguments.count > 1 {
                    mask = routeEntryArguments[1]
                } else {
                    mask = nil
                }
                if routeEntryArguments.count > 2 {
                    gateway = routeEntryArguments[2]
                } else {
                    gateway = defaultGateway4
                }
                routes4.append(IPv4Settings.Route(address, mask, gateway))
            }

            ipv4 = IPv4Settings(
                address: address4,
                addressMask: addressMask4,
                defaultGateway: defaultGateway4,
                routes: routes4
            )

            // MARK: Routing (IPv6)
            
            Regex.ifconfig6.enumerateArguments(in: message) {
                optIfconfig6Arguments = $0
            }
            if let ifconfig6Arguments = optIfconfig6Arguments, ifconfig6Arguments.count == 2 {
                let address6Components = ifconfig6Arguments[0].components(separatedBy: "/")
                guard address6Components.count == 2 else {
                    throw SessionError.malformedPushReply
                }
                guard let addressPrefix6 = UInt8(address6Components[1]) else {
                    throw SessionError.malformedPushReply
                }
                let address6 = address6Components[0]
                let defaultGateway6 = ifconfig6Arguments[1]
                
                var routes6: [IPv6Settings.Route] = []
                Regex.route6.enumerateArguments(in: message) {
                    let routeEntryArguments = $0
                    
                    let destinationComponents = routeEntryArguments[0].components(separatedBy: "/")
                    guard destinationComponents.count == 2 else {
//                        throw SessionError.malformedPushReply
                        return
                    }
                    guard let prefix = UInt8(destinationComponents[1]) else {
//                        throw SessionError.malformedPushReply
                        return
                    }

                    let destination = destinationComponents[0]
                    let gateway: String?
                    if routeEntryArguments.count > 1 {
                        gateway = routeEntryArguments[1]
                    } else {
                        gateway = defaultGateway6
                    }
                    routes6.append(IPv6Settings.Route(destination, prefix, gateway))
                }

                ipv6 = IPv6Settings(
                    address: address6,
                    addressPrefixLength: addressPrefix6,
                    defaultGateway: defaultGateway6,
                    routes: routes6
                )
            } else {
                ipv6 = nil
            }

            // MARK: DNS

            Regex.dns.enumerateArguments(in: message) {
                dnsServers.append($0[1])
            }
            
            // MARK: Compression
            
            Regex.comp.enumerateComponents(in: message) {
                switch $0[0] {
                case "comp-lzo":
                    compressionFraming = .compLZO
                    usesCompression = !(($0.count == 2) && ($0[1] == "no"))
                    
                case "compress":
                    compressionFraming = .compress
                    usesCompression = ($0.count > 1)

                default:
                    break
                }
            }
            
            // MARK: Keep-alive
            
            Regex.ping.enumerateArguments(in: message) {
                ping = Int($0[0])
            }
            
            // MARK: Authentication

            Regex.authToken.enumerateArguments(in: message) {
                authToken = $0[0]
            }
            
            Regex.peerId.enumerateArguments(in: message) {
                peerId = UInt32($0[0])
            }
            
            // MARK: NCP
            
            Regex.cipher.enumerateArguments(in: message) {
                cipher = SessionProxy.Cipher(rawValue: $0[0].uppercased())
            }

            self.dnsServers = dnsServers
            self.compressionFraming = compressionFraming
            self.usesCompression = usesCompression
            self.ping = ping
            self.authToken = authToken
            self.peerId = peerId
            self.cipher = cipher
        }
        
        // MARK: CustomStringConvertible
        
        var description: String {
            let stripped = NSMutableString(string: original)
            Regex.authToken.replaceMatches(
                in: stripped,
                options: [],
                range: NSMakeRange(0, stripped.length),
                withTemplate: "auth-token"
            )
            return stripped as String
        }
    }
}
