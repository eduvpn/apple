//
//  SessionProxy+Configuration.swift
//  TunnelKit
//
//  Created by Davide De Rosa on 8/23/18.
//  Copyright (c) 2019 Davide De Rosa. All rights reserved.
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

extension SessionProxy {
    
    /// A pair of credentials for authentication.
    public struct Credentials: Codable, Equatable {

        /// The username.
        public let username: String
        
        /// The password.
        public let password: String
        
        /// :nodoc
        public init(_ username: String, _ password: String) {
            self.username = username
            self.password = password
        }
        
        // MARK: Equatable

        /// :nodoc:
        public static func ==(lhs: Credentials, rhs: Credentials) -> Bool {
            return (lhs.username == rhs.username) && (lhs.password == rhs.password)
        }
    }

    /// The available encryption algorithms.
    public enum Cipher: String, Codable, CustomStringConvertible {
        
        // WARNING: must match OpenSSL algorithm names
        
        /// AES encryption with 128-bit key size and CBC.
        case aes128cbc = "AES-128-CBC"
        
        /// AES encryption with 192-bit key size and CBC.
        case aes192cbc = "AES-192-CBC"
        
        /// AES encryption with 256-bit key size and CBC.
        case aes256cbc = "AES-256-CBC"
        
        /// AES encryption with 128-bit key size and GCM.
        case aes128gcm = "AES-128-GCM"
        
        /// AES encryption with 192-bit key size and GCM.
        case aes192gcm = "AES-192-GCM"
        
        /// AES encryption with 256-bit key size and GCM.
        case aes256gcm = "AES-256-GCM"
        
        /// Returns the key size for this cipher.
        public var keySize: Int {
            switch self {
            case .aes128cbc, .aes128gcm:
                return 128
                
            case .aes192cbc, .aes192gcm:
                return 192
                
            case .aes256cbc, .aes256gcm:
                return 256
            }
        }
        
        /// Digest should be ignored when this is `true`.
        public var embedsDigest: Bool {
            return rawValue.hasSuffix("-GCM")
        }
        
        /// Returns a generic name for this cipher.
        public var genericName: String {
            return rawValue.hasSuffix("-GCM") ? "AES-GCM" : "AES-CBC"
        }
        
        /// :nodoc:
        public var description: String {
            return rawValue
        }
    }
    
    /// The available message digest algorithms.
    public enum Digest: String, Codable, CustomStringConvertible {
        
        // WARNING: must match OpenSSL algorithm names
        
        /// SHA1 message digest.
        case sha1 = "SHA1"
        
        /// SHA224 message digest.
        case sha224 = "SHA224"

        /// SHA256 message digest.
        case sha256 = "SHA256"

        /// SHA256 message digest.
        case sha384 = "SHA384"

        /// SHA256 message digest.
        case sha512 = "SHA512"
        
        /// Returns a generic name for this digest.
        public var genericName: String {
            return "HMAC"
        }
        
        /// :nodoc:
        public var description: String {
            return "\(genericName)-\(rawValue)"
        }
    }
    
    /// Routing policy.
    public enum RoutingPolicy: String, Codable {

        /// All IPv4 traffic goes through the VPN.
        case IPv4

        /// All IPv6 traffic goes through the VPN.
        case IPv6
    }
    
    /// :nodoc:
    private struct Fallback {
        static let cipher: Cipher = .aes128cbc
        
        static let digest: Digest = .sha1
        
        static let compressionFraming: CompressionFraming = .disabled
    }
    
    /// The way to create a `SessionProxy.Configuration` object for a `SessionProxy`.
    public struct ConfigurationBuilder {

        // MARK: General
        
        /// The cipher algorithm for data encryption.
        public var cipher: SessionProxy.Cipher?
        
        /// The digest algorithm for HMAC.
        public var digest: SessionProxy.Digest?
        
        /// Compression framing, disabled by default.
        public var compressionFraming: SessionProxy.CompressionFraming?
        
        /// Compression algorithm, disabled by default.
        public var compressionAlgorithm: SessionProxy.CompressionAlgorithm?
        
        /// The CA for TLS negotiation (PEM format).
        public var ca: CryptoContainer?
        
        /// The optional client certificate for TLS negotiation (PEM format).
        public var clientCertificate: CryptoContainer?
        
        /// The private key for the certificate in `clientCertificate` (PEM format).
        public var clientKey: CryptoContainer?
        
        /// The optional TLS wrapping.
        public var tlsWrap: SessionProxy.TLSWrap?
        
        /// Sends periodical keep-alive packets if set.
        public var keepAliveInterval: TimeInterval?
        
        /// The number of seconds after which a renegotiation should be initiated. If `nil`, the client will never initiate a renegotiation.
        public var renegotiatesAfter: TimeInterval?
        
        // MARK: Client
        
        /// The server hostname (picked from first remote).
        public var hostname: String?
        
        /// The list of server endpoints.
        public var endpointProtocols: [EndpointProtocol]?
        
        /// If true, checks EKU of server certificate.
        public var checksEKU: Bool?
        
        /// Picks endpoint from `remotes` randomly.
        public var randomizeEndpoint: Bool?
        
        /// Server is patched for the PIA VPN provider.
        public var usesPIAPatches: Bool?
        
        // MARK: Server
        
        /// The auth-token returned by the server.
        public var authToken: String?
        
        /// The peer-id returned by the server.
        public var peerId: UInt32?
        
        // MARK: Routing
        
        /// The settings for IPv4. `SessionProxy` only evaluates this server-side.
        public var ipv4: IPv4Settings?
        
        /// The settings for IPv6. `SessionProxy` only evaluates this server-side.
        public var ipv6: IPv6Settings?
        
        /// The DNS servers.
        public var dnsServers: [String]?
        
        /// The search domain.
        public var searchDomain: String?

        /// The HTTP proxy.
        public var httpProxy: Proxy?
        
        /// The HTTPS proxy.
        public var httpsProxy: Proxy?
        
        /// The list of domains not passing through the proxy.
        public var proxyBypassDomains: [String]?
        
        /// Policies for redirecting traffic through the VPN gateway.
        public var routingPolicies: [RoutingPolicy]?
        
        /// :nodoc:
        public init() {
        }
        
        /**
         Builds a `SessionProxy.Configuration` object.
         
         - Returns: A `SessionProxy.Configuration` object with this builder.
         */
        public func build() -> Configuration {
            return Configuration(
                cipher: cipher,
                digest: digest,
                compressionFraming: compressionFraming,
                compressionAlgorithm: compressionAlgorithm,
                ca: ca,
                clientCertificate: clientCertificate,
                clientKey: clientKey,
                tlsWrap: tlsWrap,
                keepAliveInterval: keepAliveInterval,
                renegotiatesAfter: renegotiatesAfter,
                hostname: hostname,
                endpointProtocols: endpointProtocols,
                checksEKU: checksEKU,
                randomizeEndpoint: randomizeEndpoint,
                usesPIAPatches: usesPIAPatches,
                authToken: authToken,
                peerId: peerId,
                ipv4: ipv4,
                ipv6: ipv6,
                dnsServers: dnsServers,
                searchDomain: searchDomain,
                httpProxy: httpProxy,
                httpsProxy: httpsProxy,
                proxyBypassDomains: proxyBypassDomains,
                routingPolicies: routingPolicies
            )
        }

        // MARK: Shortcuts
        
        /// :nodoc:
        public var fallbackCipher: Cipher {
            return cipher ?? Fallback.cipher
        }
        
        /// :nodoc:
        public var fallbackDigest: Digest {
            return digest ?? Fallback.digest
        }
        
        /// :nodoc:
        public var fallbackCompressionFraming: CompressionFraming {
            return compressionFraming ?? Fallback.compressionFraming
        }
    }
    
    /// The immutable configuration for `SessionProxy`.
    public struct Configuration: Codable {

        /// - Seealso: `SessionProxy.ConfigurationBuilder.cipher`
        public let cipher: Cipher?
        
        /// - Seealso: `SessionProxy.ConfigurationBuilder.digest`
        public let digest: Digest?
        
        /// - Seealso: `SessionProxy.ConfigurationBuilder.compressionFraming`
        public let compressionFraming: CompressionFraming?
        
        /// - Seealso: `SessionProxy.ConfigurationBuilder.compressionAlgorithm`
        public let compressionAlgorithm: CompressionAlgorithm?
        
        /// - Seealso: `SessionProxy.ConfigurationBuilder.ca`
        public let ca: CryptoContainer?
        
        /// - Seealso: `SessionProxy.ConfigurationBuilder.clientCertificate`
        public let clientCertificate: CryptoContainer?
        
        /// - Seealso: `SessionProxy.ConfigurationBuilder.clientKey`
        public let clientKey: CryptoContainer?
        
        /// - Seealso: `SessionProxy.ConfigurationBuilder.tlsWrap`
        public var tlsWrap: TLSWrap?

        /// - Seealso: `SessionProxy.ConfigurationBuilder.keepAliveInterval`
        public let keepAliveInterval: TimeInterval?

        /// - Seealso: `SessionProxy.ConfigurationBuilder.renegotiatesAfter`
        public let renegotiatesAfter: TimeInterval?

        /// - Seealso: `SessionProxy.ConfigurationBuilder.hostname`
        public var hostname: String?
        
        /// - Seealso: `SessionProxy.ConfigurationBuilder.endpointProtocols`
        public var endpointProtocols: [EndpointProtocol]?

        /// - Seealso: `SessionProxy.ConfigurationBuilder.checksEKU`
        public let checksEKU: Bool?
        
        /// - Seealso: `SessionProxy.ConfigurationBuilder.randomizeEndpoint`
        public let randomizeEndpoint: Bool?
        
        /// - Seealso: `SessionProxy.ConfigurationBuilder.usesPIAPatches`
        public let usesPIAPatches: Bool?
        
        /// - Seealso: `SessionProxy.ConfigurationBuilder.authToken`
        public let authToken: String?
        
        /// - Seealso: `SessionProxy.ConfigurationBuilder.peerId`
        public let peerId: UInt32?
        
        /// - Seealso: `SessionProxy.ConfigurationBuilder.ipv4`
        public let ipv4: IPv4Settings?

        /// - Seealso: `SessionProxy.ConfigurationBuilder.ipv6`
        public let ipv6: IPv6Settings?

        /// - Seealso: `SessionProxy.ConfigurationBuilder.dnsServers`
        public let dnsServers: [String]?
        
        /// - Seealso: `SessionProxy.ConfigurationBuilder.searchDomain`
        public let searchDomain: String?
        
        /// - Seealso: `SessionProxy.ConfigurationBuilder.httpProxy`
        public var httpProxy: Proxy?
        
        /// - Seealso: `SessionProxy.ConfigurationBuilder.httpsProxy`
        public var httpsProxy: Proxy?
        
        /// - Seealso: `SessionProxy.ConfigurationBuilder.proxyBypassDomains`
        public var proxyBypassDomains: [String]?
        
        /// - Seealso: `SessionProxy.ConfigurationBuilder.routingPolicies`
        public var routingPolicies: [RoutingPolicy]?
        
        // MARK: Shortcuts
        
        /// :nodoc:
        public var fallbackCipher: Cipher {
            return cipher ?? Fallback.cipher
        }

        /// :nodoc:
        public var fallbackDigest: Digest {
            return digest ?? Fallback.digest
        }

        /// :nodoc:
        public var fallbackCompressionFraming: CompressionFraming {
            return compressionFraming ?? Fallback.compressionFraming
        }
    }
}

// MARK: Modification

extension SessionProxy.Configuration {
    
    /**
     Returns a `SessionProxy.ConfigurationBuilder` to use this configuration as a starting point for a new one.
     
     - Returns: An editable `SessionProxy.ConfigurationBuilder` initialized with this configuration.
     */
    public func builder() -> SessionProxy.ConfigurationBuilder {
        var builder = SessionProxy.ConfigurationBuilder()
        builder.cipher = cipher
        builder.digest = digest
        builder.compressionFraming = compressionFraming
        builder.compressionAlgorithm = compressionAlgorithm
        builder.ca = ca
        builder.clientCertificate = clientCertificate
        builder.clientKey = clientKey
        builder.tlsWrap = tlsWrap
        builder.keepAliveInterval = keepAliveInterval
        builder.renegotiatesAfter = renegotiatesAfter
        builder.endpointProtocols = endpointProtocols
        builder.checksEKU = checksEKU
        builder.randomizeEndpoint = randomizeEndpoint
        builder.usesPIAPatches = usesPIAPatches
        builder.authToken = authToken
        builder.peerId = peerId
        builder.ipv4 = ipv4
        builder.ipv6 = ipv6
        builder.dnsServers = dnsServers
        builder.searchDomain = searchDomain
        builder.httpProxy = httpProxy
        builder.httpsProxy = httpsProxy
        builder.proxyBypassDomains = proxyBypassDomains
        builder.routingPolicies = routingPolicies
        return builder
    }
}

/// Encapsulates the IPv4 settings for the tunnel.
public struct IPv4Settings: Codable, CustomStringConvertible {
    
    /// Represents an IPv4 route in the routing table.
    public struct Route: Codable, CustomStringConvertible {
        
        /// The destination host or subnet.
        public let destination: String
        
        /// The address mask.
        public let mask: String
        
        /// The address of the gateway (uses default gateway if not set).
        public let gateway: String
        
        init(_ destination: String, _ mask: String?, _ gateway: String) {
            self.destination = destination
            self.mask = mask ?? "255.255.255.255"
            self.gateway = gateway
        }
        
        // MARK: CustomStringConvertible
        
        /// :nodoc:
        public var description: String {
            return "{\(destination.maskedDescription)/\(mask) \(gateway.maskedDescription)}"
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
public struct IPv6Settings: Codable, CustomStringConvertible {
    
    /// Represents an IPv6 route in the routing table.
    public struct Route: Codable, CustomStringConvertible {
        
        /// The destination host or subnet.
        public let destination: String
        
        /// The address prefix length.
        public let prefixLength: UInt8
        
        /// The address of the gateway (uses default gateway if not set).
        public let gateway: String
        
        init(_ destination: String, _ prefixLength: UInt8?, _ gateway: String) {
            self.destination = destination
            self.prefixLength = prefixLength ?? 3
            self.gateway = gateway
        }
        
        // MARK: CustomStringConvertible
        
        /// :nodoc:
        public var description: String {
            return "{\(destination.maskedDescription)/\(prefixLength) \(gateway.maskedDescription)}"
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

/// Encapsulate a proxy setting.
public struct Proxy: Codable, RawRepresentable, CustomStringConvertible {

    /// The proxy address.
    public let address: String

    /// The proxy port.
    public let port: UInt16
    
    /// :nodoc:
    public init(_ address: String, _ port: UInt16) {
        self.address = address
        self.port = port
    }

    // MARK: RawRepresentable
    
    /// :nodoc:
    public var rawValue: String {
        return "\(address):\(port)"
    }
    
    /// :nodoc:
    public init?(rawValue: String) {
        let comps = rawValue.components(separatedBy: ":")
        guard comps.count == 2, let port = UInt16(comps[1]) else {
            return nil
        }
        self.init(comps[0], port)
    }
    
    // MARK: CustomStringConvertible
    
    /// :nodoc:
    public var description: String {
        return rawValue
    }
}

/// :nodoc:
extension EndpointProtocol: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        guard let proto = try EndpointProtocol(rawValue: container.decode(String.self)) else {
            throw ConfigurationError.malformed(option: "remote/proto")
        }
        self.init(proto.socketType, proto.port)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
