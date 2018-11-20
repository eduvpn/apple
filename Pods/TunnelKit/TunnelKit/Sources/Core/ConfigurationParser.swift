//
//  ConfigurationParser.swift
//  TunnelKit
//
//  Created by Davide De Rosa on 9/5/18.
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

import Foundation
import SwiftyBeaver

private let log = SwiftyBeaver.self

/// Provides methods to parse a `SessionProxy.Configuration` from an .ovpn configuration file.
public class ConfigurationParser {

    /// Error raised by the parser, with details about the line that triggered it.
    public enum ParsingError: Error {

        /// The file misses a required option.
        case missingConfiguration(option: String)

        /// The file includes an unsupported option.
        case unsupportedConfiguration(option: String)
    }

    /// Result of the parser.
    public struct ParsingResult {

        /// Original URL of the configuration file, if parsed from an URL.
        public let url: URL?

        /// The main endpoint hostname.
        public let hostname: String
        
        /// The list of `EndpointProtocol` to which the client can connect to.
        public let protocols: [EndpointProtocol]

        /// The overall parsed `SessionProxy.Configuration`.
        public let configuration: SessionProxy.Configuration

        /// The lines of the configuration file stripped of any sensitive data. Lines that
        /// the parser does not recognize are discarded in the first place.
        ///
        /// - Seealso: `ConfigurationParser.parsed(...)`
        public let strippedLines: [String]?
        
        /// Holds an optional `ParsingError` that didn't block the parser, but it would be worth taking care of.
        public let warning: ParsingError?
    }
    
    private struct Regex {
        static let proto = NSRegularExpression("^proto +(udp6?|tcp6?)")

        static let port = NSRegularExpression("^port +\\d+")
        
        static let remote = NSRegularExpression("^remote +[^ ]+( +\\d+)?( +(udp6?|tcp6?))?")

        static let cipher = NSRegularExpression("^cipher +[\\w\\-]+")

        static let auth = NSRegularExpression("^auth +[\\w\\-]+")
        
        static let compLZO = NSRegularExpression("^comp-lzo.*")

        static let compress = NSRegularExpression("^compress.*")
        
        static let ping = NSRegularExpression("^ping +\\d+")

        static let renegSec = NSRegularExpression("^reneg-sec +\\d+")

        static let keyDirection = NSRegularExpression("^key-direction +\\d")
        
        static let blockBegin = NSRegularExpression("^<[\\w\\-]+>")
        
        static let blockEnd = NSRegularExpression("^<\\/[\\w\\-]+>")

        // unsupported

//        static let fragment = NSRegularExpression("^fragment +\\d+")
        static let fragment = NSRegularExpression("^fragment")

        static let proxy = NSRegularExpression("^\\w+-proxy")

        static let externalFiles = NSRegularExpression("^(ca|cert|key|tls-auth|tls-crypt) ")
    }
    
    /**
     Parses an .ovpn file from an URL.
     
     - Parameter url: The URL of the configuration file.
     - Parameter returnsStripped: When `true`, stores the stripped file into `ParsingResult.strippedLines`. Defaults to `false`.
     - Returns: The `ParsingResult` outcome of the parsing.
     - Throws: `ParsingError` if the configuration file is wrong or incomplete.
     */
    public static func parsed(fromURL url: URL, returnsStripped: Bool = false) throws -> ParsingResult {
        let lines = try String(contentsOf: url).trimmedLines()
        return try parsed(fromLines: lines, originalURL: url, returnsStripped: returnsStripped)
    }

    /**
     Parses an .ovpn file as an array of lines.
     
     - Parameter lines: The array of lines holding the configuration.
     - Parameter url: The optional URL of the configuration file.
     - Parameter returnsStripped: When `true`, stores the stripped file into `ParsingResult.strippedLines`. Defaults to `false`.
     - Returns: The `ParsingResult` outcome of the parsing.
     - Throws: `ParsingError` if the configuration file is wrong or incomplete.
     */
    public static func parsed(fromLines lines: [String], originalURL: URL? = nil, returnsStripped: Bool = false) throws -> ParsingResult {
        var strippedLines: [String]? = returnsStripped ? [] : nil
        var warning: ParsingError? = nil

        var defaultProto: SocketType?
        var defaultPort: UInt16?
        var remotes: [(String, UInt16?, SocketType?)] = []

        var cipher: SessionProxy.Cipher?
        var digest: SessionProxy.Digest?
        var compressionFraming: SessionProxy.CompressionFraming = .disabled
        var optCA: CryptoContainer?
        var clientCertificate: CryptoContainer?
        var clientKey: CryptoContainer?
        var keepAliveSeconds: TimeInterval?
        var renegotiateAfterSeconds: TimeInterval?
        var keyDirection: StaticKey.Direction?
        var tlsStrategy: SessionProxy.TLSWrap.Strategy?
        var tlsKeyLines: [Substring]?
        var tlsWrap: SessionProxy.TLSWrap?

        var currentBlockName: String?
        var currentBlock: [String] = []
        var unsupportedError: ParsingError? = nil

        log.verbose("Configuration file:")
        for line in lines {
            log.verbose(line)

            var isHandled = false
            var strippedLine = line
            defer {
                if isHandled {
                    strippedLines?.append(strippedLine)
                }
            }

            Regex.blockBegin.enumerateComponents(in: line) {
                isHandled = true
                let tag = $0.first!
                let from = tag.index(after: tag.startIndex)
                let to = tag.index(before: tag.endIndex)

                currentBlockName = String(tag[from..<to])
                currentBlock = []
            }
            Regex.blockEnd.enumerateComponents(in: line) {
                isHandled = true
                let tag = $0.first!
                let from = tag.index(tag.startIndex, offsetBy: 2)
                let to = tag.index(before: tag.endIndex)

                let blockName = String(tag[from..<to])
                guard blockName == currentBlockName else {
                    return
                }

                // first is opening tag
                currentBlock.removeFirst()
                switch blockName {
                case "ca":
                    optCA = CryptoContainer(pem: currentBlock.joined(separator: "\n"))
                    
                case "cert":
                    clientCertificate = CryptoContainer(pem: currentBlock.joined(separator: "\n"))
                    
                case "key":
                    let container = CryptoContainer(pem: currentBlock.joined(separator: "\n"))
                    clientKey = container
                    if container.isEncrypted {
                        unsupportedError = ParsingError.unsupportedConfiguration(option: "encrypted client certificate key")
                    }
                    
                case "tls-auth":
                    tlsKeyLines = currentBlock.map { Substring($0) }
                    tlsStrategy = .auth
                    
                case "tls-crypt":
                    tlsKeyLines = currentBlock.map { Substring($0) }
                    tlsStrategy = .crypt
                    
                default:
                    break
                }
                currentBlockName = nil
                currentBlock = []
            }
            if let _ = currentBlockName {
                currentBlock.append(line)
                continue
            }
            
            Regex.proto.enumerateArguments(in: line) {
                isHandled = true
                guard let str = $0.first else {
                    return
                }
                defaultProto = SocketType(protoString: str)
                if defaultProto == nil {
                    unsupportedError = ParsingError.unsupportedConfiguration(option: "proto \(str)")
                }
            }
            Regex.port.enumerateArguments(in: line) {
                isHandled = true
                guard let str = $0.first else {
                    return
                }
                defaultPort = UInt16(str)
            }
            Regex.remote.enumerateArguments(in: line) {
                isHandled = true
                guard let hostname = $0.first else {
                    return
                }
                var port: UInt16?
                var proto: SocketType?
                var strippedComponents = ["remote", "<hostname>"]
                if $0.count > 1 {
                    port = UInt16($0[1])
                    strippedComponents.append($0[1])
                }
                if $0.count > 2 {
                    proto = SocketType(protoString: $0[2])
                    strippedComponents.append($0[2])
                }
                remotes.append((hostname, port, proto))

                // replace private data
                strippedLine = strippedComponents.joined(separator: " ")
            }
            Regex.cipher.enumerateArguments(in: line) {
                isHandled = true
                guard let rawValue = $0.first else {
                    return
                }
                cipher = SessionProxy.Cipher(rawValue: rawValue.uppercased())
                if cipher == nil {
                    unsupportedError = ParsingError.unsupportedConfiguration(option: "cipher \(rawValue)")
                }
            }
            Regex.auth.enumerateArguments(in: line) {
                isHandled = true
                guard let rawValue = $0.first else {
                    return
                }
                digest = SessionProxy.Digest(rawValue: rawValue.uppercased())
                if digest == nil {
                    unsupportedError = ParsingError.unsupportedConfiguration(option: "auth \(rawValue)")
                }
            }
            Regex.compLZO.enumerateArguments(in: line) {
                isHandled = true
                compressionFraming = .compLZO
                
                guard let arg = $0.first else {
                    warning = warning ?? .unsupportedConfiguration(option: line)
                    return
                }
                guard arg == "no" else {
                    unsupportedError = .unsupportedConfiguration(option: line)
                    return
                }
            }
            Regex.compress.enumerateArguments(in: line) {
                isHandled = true
                compressionFraming = .compress

                guard $0.isEmpty else {
                    unsupportedError = .unsupportedConfiguration(option: line)
                    return
                }
            }
            Regex.keyDirection.enumerateArguments(in: line) {
                isHandled = true
                guard let arg = $0.first, let value = Int(arg) else {
                    return
                }
                keyDirection = StaticKey.Direction(rawValue: value)
            }
            Regex.ping.enumerateArguments(in: line) {
                isHandled = true
                guard let arg = $0.first else {
                    return
                }
                keepAliveSeconds = TimeInterval(arg)
            }
            Regex.renegSec.enumerateArguments(in: line) {
                isHandled = true
                guard let arg = $0.first else {
                    return
                }
                renegotiateAfterSeconds = TimeInterval(arg)
            }
            Regex.fragment.enumerateArguments(in: line) { (_) in
                unsupportedError = ParsingError.unsupportedConfiguration(option: "fragment")
            }
            Regex.proxy.enumerateArguments(in: line) { (_) in
                unsupportedError = ParsingError.unsupportedConfiguration(option: "proxy: \"\(line)\"")
            }
            Regex.externalFiles.enumerateArguments(in: line) { (_) in
                unsupportedError = ParsingError.unsupportedConfiguration(option: "external file: \"\(line)\"")
            }
            if line.contains("mtu") || line.contains("mssfix") {
                isHandled = true
            }

            if let error = unsupportedError {
                throw error
            }
        }
        
        guard let ca = optCA else {
            throw ParsingError.missingConfiguration(option: "ca")
        }
        
        // XXX: only reads first remote
//        hostnames = remotes.map { $0.0 }
        guard !remotes.isEmpty else {
            throw ParsingError.missingConfiguration(option: "remote")
        }
        let hostname = remotes[0].0
        
        defaultProto = defaultProto ?? .udp
        defaultPort = defaultPort ?? 1194

        // XXX: reads endpoints from remotes with matching hostname
        var endpointProtocols: [EndpointProtocol] = []
        remotes.forEach {
            guard $0.0 == hostname else {
                return
            }
            guard let port = $0.1 ?? defaultPort else {
                return
            }
            guard let socketType = $0.2 ?? defaultProto else {
                return
            }
            endpointProtocols.append(EndpointProtocol(socketType, port))
        }
        
        assert(!endpointProtocols.isEmpty, "Must define an endpoint protocol")

        if let keyLines = tlsKeyLines, let strategy = tlsStrategy {
            let optKey: StaticKey?
            switch strategy {
            case .auth:
                optKey = StaticKey(lines: keyLines, direction: keyDirection)

            case .crypt:
                optKey = StaticKey(lines: keyLines, direction: .client)
            }
            if let key = optKey {
                tlsWrap = SessionProxy.TLSWrap(strategy: strategy, key: key)
            }
        }

        var sessionBuilder = SessionProxy.ConfigurationBuilder(ca: ca)
        sessionBuilder.cipher = cipher ?? .aes128cbc
        sessionBuilder.digest = digest ?? .sha1
        sessionBuilder.compressionFraming = compressionFraming
        sessionBuilder.tlsWrap = tlsWrap
        sessionBuilder.clientCertificate = clientCertificate
        sessionBuilder.clientKey = clientKey
        sessionBuilder.keepAliveInterval = keepAliveSeconds
        sessionBuilder.renegotiatesAfter = renegotiateAfterSeconds

        return ParsingResult(
            url: originalURL,
            hostname: hostname,
            protocols: endpointProtocols,
            configuration: sessionBuilder.build(),
            strippedLines: strippedLines,
            warning: warning
        )
    }
}

private extension SocketType {
    init?(protoString: String) {
        var str = protoString
        if str.hasSuffix("6") {
            str.removeLast()
        }
        self.init(rawValue: str.uppercased())
    }
}

extension String {
    func trimmedLines() -> [String] {
        return components(separatedBy: .newlines).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter {
            !$0.isEmpty
        }
    }
}

extension CryptoContainer {
    var isEncrypted: Bool {
        return pem.contains("ENCRYPTED")
    }
}
