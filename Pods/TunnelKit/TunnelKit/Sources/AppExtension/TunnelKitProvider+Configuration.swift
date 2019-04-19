//
//  TunnelKitProvider+Configuration.swift
//  TunnelKit
//
//  Created by Davide De Rosa on 10/23/17.
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
import NetworkExtension
import SwiftyBeaver

private let log = SwiftyBeaver.self

extension TunnelKitProvider {

    // MARK: Configuration
    
    /// The way to create a `TunnelKitProvider.Configuration` object for the tunnel profile.
    public struct ConfigurationBuilder {

        /// :nodoc:
        public static let defaults = Configuration(
            prefersResolvedAddresses: false,
            resolvedAddresses: nil,
            endpointProtocols: nil,
            mtu: 1250,
            sessionConfiguration: SessionProxy.ConfigurationBuilder().build(),
            shouldDebug: false,
            debugLogFormat: nil,
            masksPrivateData: true
        )
        
        /// Prefers resolved addresses over DNS resolution. `resolvedAddresses` must be set and non-empty. Default is `false`.
        ///
        /// - Seealso: `fallbackServerAddresses`
        public var prefersResolvedAddresses: Bool
        
        /// Resolved addresses in case DNS fails or `prefersResolvedAddresses` is `true`.
        public var resolvedAddresses: [String]?
        
        /// The MTU of the link.
        public var mtu: Int
        
        /// The session configuration.
        public var sessionConfiguration: SessionProxy.Configuration
        
        // MARK: Debugging
        
        /// Enables debugging.
        public var shouldDebug: Bool
        
        /// Optional debug log format (SwiftyBeaver format).
        public var debugLogFormat: String?
        
        /// Mask private data in debug log (default is `true`).
        public var masksPrivateData: Bool?
        
        // MARK: Building
        
        /**
         Default initializer.
         
         - Parameter ca: The CA certificate.
         */
        public init(sessionConfiguration: SessionProxy.Configuration) {
            prefersResolvedAddresses = ConfigurationBuilder.defaults.prefersResolvedAddresses
            resolvedAddresses = nil
            mtu = ConfigurationBuilder.defaults.mtu
            self.sessionConfiguration = sessionConfiguration
            shouldDebug = ConfigurationBuilder.defaults.shouldDebug
            debugLogFormat = ConfigurationBuilder.defaults.debugLogFormat
            masksPrivateData = ConfigurationBuilder.defaults.masksPrivateData
        }
        
        fileprivate init(providerConfiguration: [String: Any]) throws {
            let S = Configuration.Keys.self

            prefersResolvedAddresses = providerConfiguration[S.prefersResolvedAddresses] as? Bool ?? ConfigurationBuilder.defaults.prefersResolvedAddresses
            resolvedAddresses = providerConfiguration[S.resolvedAddresses] as? [String]
            mtu = providerConfiguration[S.mtu] as? Int ?? ConfigurationBuilder.defaults.mtu
            
            //

            guard let caPEM = providerConfiguration[S.ca] as? String else {
                throw ProviderConfigurationError.parameter(name: "protocolConfiguration.providerConfiguration[\(S.ca)]")
            }

            var sessionConfigurationBuilder = SessionProxy.ConfigurationBuilder()
            if let cipherAlgorithm = providerConfiguration[S.cipherAlgorithm] as? String {
                sessionConfigurationBuilder.cipher = SessionProxy.Cipher(rawValue: cipherAlgorithm)
            }
            if let digestAlgorithm = providerConfiguration[S.digestAlgorithm] as? String {
                sessionConfigurationBuilder.digest = SessionProxy.Digest(rawValue: digestAlgorithm)
            }
            if let compressionFramingValue = providerConfiguration[S.compressionFraming] as? Int, let compressionFraming = SessionProxy.CompressionFraming(rawValue: compressionFramingValue) {
                sessionConfigurationBuilder.compressionFraming = compressionFraming
            } else {
                sessionConfigurationBuilder.compressionFraming = ConfigurationBuilder.defaults.sessionConfiguration.compressionFraming
            }
            if let compressionAlgorithmValue = providerConfiguration[S.compressionAlgorithm] as? Int, let compressionAlgorithm = SessionProxy.CompressionAlgorithm(rawValue: compressionAlgorithmValue) {
                sessionConfigurationBuilder.compressionAlgorithm = compressionAlgorithm
            } else {
                sessionConfigurationBuilder.compressionAlgorithm = ConfigurationBuilder.defaults.sessionConfiguration.compressionAlgorithm
            }
            sessionConfigurationBuilder.ca = CryptoContainer(pem: caPEM)
            if let clientPEM = providerConfiguration[S.clientCertificate] as? String {
                guard let keyPEM = providerConfiguration[S.clientKey] as? String else {
                    throw ProviderConfigurationError.parameter(name: "protocolConfiguration.providerConfiguration[\(S.clientKey)]")
                }
                sessionConfigurationBuilder.clientCertificate = CryptoContainer(pem: clientPEM)
                sessionConfigurationBuilder.clientKey = CryptoContainer(pem: keyPEM)
            }
            if let tlsWrapData = providerConfiguration[S.tlsWrap] as? Data {
                do {
                    sessionConfigurationBuilder.tlsWrap = try SessionProxy.TLSWrap.deserialized(tlsWrapData)
                } catch {
                    throw ProviderConfigurationError.parameter(name: "protocolConfiguration.providerConfiguration[\(S.tlsWrap)]")
                }
            }
            sessionConfigurationBuilder.keepAliveInterval = providerConfiguration[S.keepAlive] as? TimeInterval ?? ConfigurationBuilder.defaults.sessionConfiguration.keepAliveInterval
            sessionConfigurationBuilder.renegotiatesAfter = providerConfiguration[S.renegotiatesAfter] as? TimeInterval ?? ConfigurationBuilder.defaults.sessionConfiguration.renegotiatesAfter
            guard let endpointProtocolsStrings = providerConfiguration[S.endpointProtocols] as? [String], !endpointProtocolsStrings.isEmpty else {
                throw ProviderConfigurationError.parameter(name: "protocolConfiguration.providerConfiguration[\(S.endpointProtocols)] is nil or empty")
            }
            sessionConfigurationBuilder.endpointProtocols = try endpointProtocolsStrings.map {
                guard let ep = EndpointProtocol(rawValue: $0) else {
                    throw ProviderConfigurationError.parameter(name: "protocolConfiguration.providerConfiguration[\(S.endpointProtocols)] has a badly formed element")
                }
                return ep
            }
            sessionConfigurationBuilder.checksEKU = providerConfiguration[S.checksEKU] as? Bool ?? ConfigurationBuilder.defaults.sessionConfiguration.checksEKU
            sessionConfigurationBuilder.randomizeEndpoint = providerConfiguration[S.randomizeEndpoint] as? Bool ?? ConfigurationBuilder.defaults.sessionConfiguration.randomizeEndpoint
            sessionConfigurationBuilder.usesPIAPatches = providerConfiguration[S.usesPIAPatches] as? Bool ?? ConfigurationBuilder.defaults.sessionConfiguration.usesPIAPatches
            sessionConfigurationBuilder.dnsServers = providerConfiguration[S.dnsServers] as? [String]
            sessionConfigurationBuilder.searchDomain = providerConfiguration[S.searchDomain] as? String
            if let proxyString = providerConfiguration[S.httpProxy] as? String {
                guard let proxy = Proxy(rawValue: proxyString) else {
                    throw ProviderConfigurationError.parameter(name: "protocolConfiguration.providerConfiguration[\(S.httpProxy)] has a badly formed element")
                }
                sessionConfigurationBuilder.httpProxy = proxy
            }
            if let proxyString = providerConfiguration[S.httpsProxy] as? String {
                guard let proxy = Proxy(rawValue: proxyString) else {
                    throw ProviderConfigurationError.parameter(name: "protocolConfiguration.providerConfiguration[\(S.httpsProxy)] has a badly formed element")
                }
                sessionConfigurationBuilder.httpsProxy = proxy
            }
            sessionConfigurationBuilder.proxyBypassDomains = providerConfiguration[S.proxyBypassDomains] as? [String]
            sessionConfiguration = sessionConfigurationBuilder.build()

            shouldDebug = providerConfiguration[S.debug] as? Bool ?? ConfigurationBuilder.defaults.shouldDebug
            if shouldDebug {
                debugLogFormat = providerConfiguration[S.debugLogFormat] as? String
            }
            masksPrivateData = providerConfiguration[S.masksPrivateData] as? Bool ?? ConfigurationBuilder.defaults.masksPrivateData

            guard !prefersResolvedAddresses || !(resolvedAddresses?.isEmpty ?? true) else {
                throw ProviderConfigurationError.parameter(name: "protocolConfiguration.providerConfiguration[\(S.prefersResolvedAddresses)] is true but no [\(S.resolvedAddresses)]")
            }
        }
        
        /**
         Builds a `TunnelKitProvider.Configuration` object that will connect to the provided endpoint.
         
         - Returns: A `TunnelKitProvider.Configuration` object with this builder and the additional method parameters.
         */
        public func build() -> Configuration {
            return Configuration(
                prefersResolvedAddresses: prefersResolvedAddresses,
                resolvedAddresses: resolvedAddresses,
                endpointProtocols: nil,
                mtu: mtu,
                sessionConfiguration: sessionConfiguration,
                shouldDebug: shouldDebug,
                debugLogFormat: shouldDebug ? debugLogFormat : nil,
                masksPrivateData: masksPrivateData
            )
        }
    }
    
    /// Offers a bridge between the abstract `TunnelKitProvider.ConfigurationBuilder` and a concrete `NETunnelProviderProtocol` profile.
    public struct Configuration: Codable {
        struct Keys {
            static let appGroup = "AppGroup"
            
            static let prefersResolvedAddresses = "PrefersResolvedAddresses"

            static let resolvedAddresses = "ResolvedAddresses"

            static let mtu = "MTU"
            
            // MARK: SessionConfiguration

            static let cipherAlgorithm = "CipherAlgorithm"
            
            static let digestAlgorithm = "DigestAlgorithm"
            
            static let compressionFraming = "CompressionFraming"
            
            static let compressionAlgorithm = "CompressionAlgorithm"
            
            static let ca = "CA"
            
            static let clientCertificate = "ClientCertificate"
            
            static let clientKey = "ClientKey"
            
            static let tlsWrap = "TLSWrap"

            static let keepAlive = "KeepAlive"
            
            static let endpointProtocols = "EndpointProtocols"
            
            static let renegotiatesAfter = "RenegotiatesAfter"
            
            static let checksEKU = "ChecksEKU"

            static let randomizeEndpoint = "RandomizeEndpoint"
            
            static let usesPIAPatches = "UsesPIAPatches"
            
            static let dnsServers = "DNSServers"
            
            static let searchDomain = "SearchDomain"
            
            static let httpProxy = "HTTPProxy"
            
            static let httpsProxy = "HTTPSProxy"
            
            static let proxyBypassDomains = "ProxyBypassDomains"
            
            // MARK: Debugging
            
            static let debug = "Debug"
            
            static let debugLogFormat = "DebugLogFormat"

            static let masksPrivateData = "MasksPrivateData"
        }
        
        /// - Seealso: `TunnelKitProvider.ConfigurationBuilder.prefersResolvedAddresses`
        public let prefersResolvedAddresses: Bool
        
        /// - Seealso: `TunnelKitProvider.ConfigurationBuilder.resolvedAddresses`
        public let resolvedAddresses: [String]?

        /// - Seealso: `SessionProxy.Configuration.endpointProtocols`
        @available(*, deprecated)
        public var endpointProtocols: [EndpointProtocol]?
        
        /// - Seealso: `TunnelKitProvider.ConfigurationBuilder.mtu`
        public let mtu: Int
        
        /// - Seealso: `TunnelKitProvider.ConfigurationBuilder.sessionConfiguration`
        public let sessionConfiguration: SessionProxy.Configuration
        
        /// - Seealso: `TunnelKitProvider.ConfigurationBuilder.shouldDebug`
        public let shouldDebug: Bool
        
        /// - Seealso: `TunnelKitProvider.ConfigurationBuilder.debugLogFormat`
        public let debugLogFormat: String?
        
        /// - Seealso: `TunnelKitProvider.ConfigurationBuilder.masksPrivateData`
        public let masksPrivateData: Bool?
        
        // MARK: Shortcuts

        static let debugLogFilename = "debug.log"

        static let lastErrorKey = "TunnelKitLastError"

        fileprivate static let dataCountKey = "TunnelKitDataCount"
        
        /**
         Returns the URL of the latest debug log.

         - Parameter in: The app group where to locate the log file.
         - Returns: The URL of the debug log, if any.
         */
        public func urlForLog(in appGroup: String) -> URL? {
            guard shouldDebug else {
                return nil
            }
            guard let parentURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
                return nil
            }
            return parentURL.appendingPathComponent(Configuration.debugLogFilename)
        }

        /**
         Returns the content of the latest debug log.
         
         - Parameter in: The app group where to locate the log file.
         - Returns: The content of the debug log, if any.
         */
        public func existingLog(in appGroup: String) -> String? {
            guard let url = urlForLog(in: appGroup) else {
                return nil
            }
            return try? String(contentsOf: url)
        }
        
        /**
         Returns the last error reported by the tunnel, if any.
         
         - Parameter in: The app group where to locate the error key.
         - Returns: The last tunnel error, if any.
         */
        public func lastError(in appGroup: String) -> ProviderError? {
            guard let rawValue = UserDefaults(suiteName: appGroup)?.string(forKey: Configuration.lastErrorKey) else {
                return nil
            }
            return ProviderError(rawValue: rawValue)
        }

        /**
         Clear the last error status.
         
         - Parameter in: The app group where to locate the error key.
         */
        public func clearLastError(in appGroup: String) {
            UserDefaults(suiteName: appGroup)?.removeObject(forKey: Configuration.lastErrorKey)
        }
        
        /**
         Returns the most recent (received, sent) count in bytes.
         
         - Parameter in: The app group where to locate the count pair.
         - Returns: The bytes count pair, if any.
         */
        public func dataCount(in appGroup: String) -> (Int, Int)? {
            guard let rawValue = UserDefaults(suiteName: appGroup)?.dataCountArray else {
                return nil
            }
            guard rawValue.count == 2 else {
                return nil
            }
            return (rawValue[0], rawValue[1])
        }
        
        // MARK: API
        
        /**
         Parses the app group from a provider configuration map.
         
         - Parameter from: The map to parse.
         - Returns: The parsed app group.
         - Throws: `ProviderError.configuration` if `providerConfiguration` does not contain an app group.
         */
        public static func appGroup(from providerConfiguration: [String: Any]) throws -> String {
            guard let appGroup = providerConfiguration[Keys.appGroup] as? String else {
                throw ProviderConfigurationError.parameter(name: "protocolConfiguration.providerConfiguration[\(Keys.appGroup)]")
            }
            return appGroup
        }
        
        /**
         Parses a new `TunnelKitProvider.Configuration` object from a provider configuration map.
         
         - Parameter from: The map to parse.
         - Returns: The parsed `TunnelKitProvider.Configuration` object.
         - Throws: `ProviderError.configuration` if `providerConfiguration` is incomplete.
         */
        public static func parsed(from providerConfiguration: [String: Any]) throws -> Configuration {
            let builder = try ConfigurationBuilder(providerConfiguration: providerConfiguration)
            return builder.build()
        }
        
        /**
         Returns a dictionary representation of this configuration for use with `NETunnelProviderProtocol.providerConfiguration`.

         - Parameter appGroup: The name of the app group in which the tunnel extension lives in.
         - Returns: The dictionary representation of `self`.
         */
        public func generatedProviderConfiguration(appGroup: String) -> [String: Any] {
            let S = Keys.self
            
            guard let ca = sessionConfiguration.ca else {
                fatalError("No sessionConfiguration.ca set")
            }
            guard let endpointProtocols = sessionConfiguration.endpointProtocols else {
                fatalError("No sessionConfiguration.endpointProtocols set")
            }

            var dict: [String: Any] = [
                S.appGroup: appGroup,
                S.prefersResolvedAddresses: prefersResolvedAddresses,
                S.ca: ca.pem,
                S.endpointProtocols: endpointProtocols.map { $0.rawValue },
                S.mtu: mtu,
                S.debug: shouldDebug
            ]
            if let cipher = sessionConfiguration.cipher {
                dict[S.cipherAlgorithm] = cipher.rawValue
            }
            if let digest = sessionConfiguration.digest {
                dict[S.digestAlgorithm] = digest.rawValue
            }
            if let compressionFraming = sessionConfiguration.compressionFraming {
                dict[S.compressionFraming] = compressionFraming.rawValue
            }
            if let compressionAlgorithm = sessionConfiguration.compressionAlgorithm {
                dict[S.compressionAlgorithm] = compressionAlgorithm.rawValue
            }
            if let clientCertificate = sessionConfiguration.clientCertificate {
                dict[S.clientCertificate] = clientCertificate.pem
            }
            if let clientKey = sessionConfiguration.clientKey {
                dict[S.clientKey] = clientKey.pem
            }
            if let tlsWrapData = sessionConfiguration.tlsWrap?.serialized() {
                dict[S.tlsWrap] = tlsWrapData
            }
            if let keepAliveSeconds = sessionConfiguration.keepAliveInterval {
                dict[S.keepAlive] = keepAliveSeconds
            }
            if let renegotiatesAfterSeconds = sessionConfiguration.renegotiatesAfter {
                dict[S.renegotiatesAfter] = renegotiatesAfterSeconds
            }
            if let checksEKU = sessionConfiguration.checksEKU {
                dict[S.checksEKU] = checksEKU
            }
            if let randomizeEndpoint = sessionConfiguration.randomizeEndpoint {
                dict[S.randomizeEndpoint] = randomizeEndpoint
            }
            if let usesPIAPatches = sessionConfiguration.usesPIAPatches {
                dict[S.usesPIAPatches] = usesPIAPatches
            }
            if let dnsServers = sessionConfiguration.dnsServers {
                dict[S.dnsServers] = dnsServers
            }
            if let searchDomain = sessionConfiguration.searchDomain {
                dict[S.searchDomain] = searchDomain
            }
            if let httpProxy = sessionConfiguration.httpProxy {
                dict[S.httpProxy] = httpProxy.rawValue
            }
            if let httpsProxy = sessionConfiguration.httpsProxy {
                dict[S.httpsProxy] = httpsProxy.rawValue
            }
            if let proxyBypassDomains = sessionConfiguration.proxyBypassDomains {
                dict[S.proxyBypassDomains] = proxyBypassDomains
            }
            //
            if let resolvedAddresses = resolvedAddresses {
                dict[S.resolvedAddresses] = resolvedAddresses
            }
            if let debugLogFormat = debugLogFormat {
                dict[S.debugLogFormat] = debugLogFormat
            }
            if let masksPrivateData = masksPrivateData {
                dict[S.masksPrivateData] = masksPrivateData
            }
            return dict
        }
        
        /**
         Generates a `NETunnelProviderProtocol` from this configuration.
         
         - Parameter bundleIdentifier: The provider bundle identifier required to locate the tunnel extension.
         - Parameter appGroup: The name of the app group in which the tunnel extension lives in.
         - Parameter credentials: The optional credentials to authenticate with.
         - Returns: The generated `NETunnelProviderProtocol` object.
         - Throws: `ProviderError.credentials` if unable to store `credentials.password` to the `appGroup` keychain.
         */
        public func generatedTunnelProtocol(withBundleIdentifier bundleIdentifier: String, appGroup: String, credentials: SessionProxy.Credentials? = nil) throws -> NETunnelProviderProtocol {
            let protocolConfiguration = NETunnelProviderProtocol()
            
            protocolConfiguration.providerBundleIdentifier = bundleIdentifier
            protocolConfiguration.serverAddress = sessionConfiguration.hostname ?? resolvedAddresses?.first
            if let username = credentials?.username, let password = credentials?.password {
                let keychain = Keychain(group: appGroup)
                do {
                    try keychain.set(password: password, for: username, label: Bundle.main.bundleIdentifier)
                } catch _ {
                    throw ProviderConfigurationError.credentials(details: "keychain.set()")
                }
                protocolConfiguration.username = username
                protocolConfiguration.passwordReference = try? keychain.passwordReference(for: username)
            }
            protocolConfiguration.providerConfiguration = generatedProviderConfiguration(appGroup: appGroup)
            
            return protocolConfiguration
        }
        
        func print(appVersion: String?) {
            guard let endpointProtocols = sessionConfiguration.endpointProtocols else {
                fatalError("No sessionConfiguration.endpointProtocols set")
            }

            if let appVersion = appVersion {
                log.info("App version: \(appVersion)")
            }
            
            log.info("\tProtocols: \(endpointProtocols)")
            log.info("\tCipher: \(sessionConfiguration.fallbackCipher)")
            log.info("\tDigest: \(sessionConfiguration.fallbackDigest)")
            log.info("\tCompression framing: \(sessionConfiguration.fallbackCompressionFraming)")
            if let compressionAlgorithm = sessionConfiguration.compressionAlgorithm, compressionAlgorithm != .disabled {
                log.info("\tCompression algorithm: \(compressionAlgorithm)")
            } else {
                log.info("\tCompression algorithm: disabled")
            }
            if let _ = sessionConfiguration.clientCertificate {
                log.info("\tClient verification: enabled")
            } else {
                log.info("\tClient verification: disabled")
            }
            if let tlsWrap = sessionConfiguration.tlsWrap {
                log.info("\tTLS wrapping: \(tlsWrap.strategy)")
            } else {
                log.info("\tTLS wrapping: disabled")
            }
            if let keepAliveSeconds = sessionConfiguration.keepAliveInterval, keepAliveSeconds > 0 {
                log.info("\tKeep-alive: \(keepAliveSeconds) seconds")
            } else {
                log.info("\tKeep-alive: never")
            }
            if let renegotiatesAfterSeconds = sessionConfiguration.renegotiatesAfter, renegotiatesAfterSeconds > 0 {
                log.info("\tRenegotiation: \(renegotiatesAfterSeconds) seconds")
            } else {
                log.info("\tRenegotiation: never")
            }
            if sessionConfiguration.checksEKU ?? false {
                log.info("\tServer EKU verification: enabled")
            } else {
                log.info("\tServer EKU verification: disabled")
            }
            if sessionConfiguration.randomizeEndpoint ?? false {
                log.info("\tRandomize endpoint: true")
            }
            if let dnsServers = sessionConfiguration.dnsServers {
                log.info("\tDNS servers: \(dnsServers.maskedDescription)")
            }
            if let searchDomain = sessionConfiguration.searchDomain {
                log.info("\tSearch domain: \(searchDomain.maskedDescription)")
            }
            if let httpProxy = sessionConfiguration.httpProxy {
                log.info("\tHTTP proxy: \(httpProxy.maskedDescription)")
            }
            if let httpsProxy = sessionConfiguration.httpsProxy {
                log.info("\tHTTPS proxy: \(httpsProxy.maskedDescription)")
            }
            if let proxyBypassDomains = sessionConfiguration.proxyBypassDomains {
                log.info("\tProxy bypass domains: \(proxyBypassDomains.maskedDescription)")
            }
            log.info("\tMTU: \(mtu)")
            log.info("\tDebug: \(shouldDebug)")
            log.info("\tMasks private data: \(masksPrivateData ?? true)")
        }
    }
}

// MARK: Modification

extension TunnelKitProvider.Configuration {

    /**
     Returns a `TunnelKitProvider.ConfigurationBuilder` to use this configuration as a starting point for a new one.

     - Returns: An editable `TunnelKitProvider.ConfigurationBuilder` initialized with this configuration.
     */
    public func builder() -> TunnelKitProvider.ConfigurationBuilder {
        var builder = TunnelKitProvider.ConfigurationBuilder(sessionConfiguration: sessionConfiguration)
        builder.prefersResolvedAddresses = prefersResolvedAddresses
        builder.resolvedAddresses = resolvedAddresses
        builder.mtu = mtu
        builder.shouldDebug = shouldDebug
        builder.debugLogFormat = debugLogFormat
        builder.masksPrivateData = masksPrivateData
        return builder
    }
}

/// :nodoc:
public extension UserDefaults {
    @objc var dataCountArray: [Int]? {
        get {
            return array(forKey: TunnelKitProvider.Configuration.dataCountKey) as? [Int]
        }
        set {
            set(newValue, forKey: TunnelKitProvider.Configuration.dataCountKey)
        }
    }

    func removeDataCountArray() {
        removeObject(forKey: TunnelKitProvider.Configuration.dataCountKey)
    }
}
