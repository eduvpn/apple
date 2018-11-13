////
////  TunnelKitProvider+FileConfiguration.swift
////  EduVPN
////
////  Created by Jeroen Leenarts on 17/10/2018.
////  Copyright © 2018 SURFNet. All rights reserved.
////
//
//import Foundation
//import TunnelKit
//import os.log
//
//enum ConfigurationError: Error {
//    case missingCA
//    case emptyRemotes
//    case unsupportedConfiguration(option: String)
//}
//
//extension TunnelKitProvider.Configuration {
//    private struct Regex {
//        private static func regex(_ pattern: String) -> NSRegularExpression {
//            return try! NSRegularExpression(pattern: pattern, options: [])
//        }
//
//        static let proto = regex("proto +(udp6?|tcp6?)")
//        static let port = regex("port +\\d+")
//        static let remote = regex("remote +[^ ]+( +\\d+)?( +(udp6?|tcp6?))?")
//        static let cipher = regex("cipher +[\\w\\-]+")
//        static let auth = regex("auth +[\\w\\-]+")
//        static let compLZO = regex("comp-lzo")
//        static let compress = regex("compress")
//        static let ping = regex("ping +\\d+")
//        static let renegSec = regex("reneg-sec +\\d+")
//        static let fragment = regex("fragment +\\d+")
//        static let keyDirection = regex("key-direction +\\d")
//        static let blockBegin = regex("<[\\w\\-]+>")
//        static let blockEnd = regex("<\\/[\\w\\-]+>")
//    }
//
//    static func parsed(from url: URL) throws -> (String, TunnelKitProvider.Configuration) {
//        let content = try String(contentsOf: url)
//        let lines = content.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
//
//        var defaultProto: TunnelKitProvider.SocketType?
//        var defaultPort: UInt16?
//        var remotes: [(String, UInt16?, TunnelKitProvider.SocketType?)] = []
//
//        var cipher: SessionProxy.Cipher?
//        var digest: SessionProxy.Digest?
//        var compressionFraming: SessionProxy.CompressionFraming = .disabled
//        var optCA: CryptoContainer?
//        var clientCertificate: CryptoContainer?
//        var clientKey: CryptoContainer?
//        var keepAliveSeconds: Int?
//        var renegotiateAfterSeconds: Int?
//
//        var currentBlockName: String?
//        var currentBlock: [String] = []
//        var unsupportedError: ConfigurationError? = nil
//
//        for line in lines {
//            os_log("Configuration file %{public}@", log: Log.general, type: .debug, line)
//
//            Regex.blockBegin.enumerateComponents(in: line) {
//                let tag = $0.first!
//                let from = tag.index(after: tag.startIndex)
//                let to = tag.index(before: tag.endIndex)
//
//                currentBlockName = String(tag[from..<to])
//                currentBlock = []
//            }
//            Regex.blockEnd.enumerateComponents(in: line) {
//                let tag = $0.first!
//                let from = tag.index(tag.startIndex, offsetBy: 2)
//                let to = tag.index(before: tag.endIndex)
//
//                let blockName = String(tag[from..<to])
//                guard blockName == currentBlockName else {
//                    return
//                }
//
//                // first is opening tag
//                currentBlock.removeFirst()
//                switch blockName {
//                case "ca":
//                    optCA = CryptoContainer(pem: currentBlock.joined(separator: "\n"))
//
//                case "cert":
//                    clientCertificate = CryptoContainer(pem: currentBlock.joined(separator: "\n"))
//
//                case "key":
//                    clientKey = CryptoContainer(pem: currentBlock.joined(separator: "\n"))
//
//                case "tls-auth", "tls-crypt":
//                    unsupportedError = ConfigurationError.unsupportedConfiguration(option: blockName)
//
//                default:
//                    break
//                }
//                currentBlockName = nil
//                currentBlock = []
//            }
//            if let _ = currentBlockName {
//                currentBlock.append(line)
//                continue
//            }
//
//            Regex.proto.enumerateArguments(in: line) {
//                guard let str = $0.first else {
//                    return
//                }
//                defaultProto = TunnelKitProvider.SocketType(protoString: str)
//            }
//            Regex.port.enumerateArguments(in: line) {
//                guard let str = $0.first else {
//                    return
//                }
//                defaultPort = UInt16(str)
//            }
//            Regex.remote.enumerateArguments(in: line) {
//                guard let hostname = $0.first else {
//                    return
//                }
//                var port: UInt16?
//                var proto: TunnelKitProvider.SocketType?
//                if $0.count > 1 {
//                    port = UInt16($0[1])
//                }
//                if $0.count > 2 {
//                    proto = TunnelKitProvider.SocketType(protoString: $0[2])
//                }
//                remotes.append((hostname, port, proto))
//            }
//            Regex.cipher.enumerateArguments(in: line) {
//                guard let rawValue = $0.first else {
//                    return
//                }
//                cipher = SessionProxy.Cipher(rawValue: rawValue.uppercased())
//            }
//            Regex.auth.enumerateArguments(in: line) {
//                guard let rawValue = $0.first else {
//                    return
//                }
//                digest = SessionProxy.Digest(rawValue: rawValue.uppercased())
//            }
//            Regex.compLZO.enumerateComponents(in: line) { _ in
//                compressionFraming = .compLZO
//            }
//            Regex.compress.enumerateComponents(in: line) { _ in
//                compressionFraming = .compress
//            }
//            Regex.ping.enumerateArguments(in: line) {
//                guard let arg = $0.first else {
//                    return
//                }
//                keepAliveSeconds = Int(arg)
//            }
//            Regex.renegSec.enumerateArguments(in: line) {
//                guard let arg = $0.first else {
//                    return
//                }
//                renegotiateAfterSeconds = Int(arg)
//            }
//            Regex.fragment.enumerateArguments(in: line) { (_) in
//                unsupportedError = ConfigurationError.unsupportedConfiguration(option: "fragment")
//            }
//
//            if let error = unsupportedError {
//                throw error
//            }
//        }
//
//        guard let ca = optCA else {
//            throw ConfigurationError.missingCA
//        }
//
//        // XXX: only reads first remote
//        //        hostnames = remotes.map { $0.0 }
//        guard !remotes.isEmpty else {
//            throw ConfigurationError.emptyRemotes
//        }
//        let hostname = remotes[0].0
//
//        defaultProto = defaultProto ?? .udp
//        defaultPort = defaultPort ?? 1194
//
//        // XXX: reads endpoints from remotes with matching hostname
//        var endpointProtocols: [TunnelKitProvider.EndpointProtocol] = []
//        remotes.forEach {
//            guard $0.0 == hostname else {
//                return
//            }
//            guard let port = $0.1 ?? defaultPort else {
//                return
//            }
//            guard let socketType = $0.2 ?? defaultProto else {
//                return
//            }
//            endpointProtocols.append(TunnelKitProvider.EndpointProtocol(socketType, port))
//        }
//
//        assert(!endpointProtocols.isEmpty, "Must define an endpoint protocol")
//
//        var builder = TunnelKitProvider.ConfigurationBuilder(ca: ca)
//        builder.endpointProtocols = endpointProtocols
//        builder.cipher = cipher ?? .aes128cbc
//        builder.digest = digest ?? .sha1
//        builder.compressionFraming = compressionFraming
//        builder.clientCertificate = clientCertificate
//        builder.clientKey = clientKey
//        builder.keepAliveSeconds = keepAliveSeconds
//        builder.renegotiatesAfterSeconds = renegotiateAfterSeconds
//
//        return (hostname, builder.build())
//    }
//}
//
//private extension TunnelKitProvider.SocketType {
//    init?(protoString: String) {
//        var str = protoString
//        if str.hasSuffix("6") {
//            str.removeLast()
//        }
//        self.init(rawValue: str.uppercased())
//    }
//}
//
//private extension NSRegularExpression {
//    func enumerateComponents(in string: String, using block: ([String]) -> Void) {
//        enumerateMatches(in: string, options: [], range: NSMakeRange(0, string.count)) { (result, flags, stop) in
//            guard let range = result?.range else {
//                return
//            }
//            let match = (string as NSString).substring(with: range)
//            let tokens = match.components(separatedBy: " ")
//            block(tokens)
//        }
//    }
//
//    func enumerateArguments(in string: String, using block: ([String]) -> Void) {
//        enumerateMatches(in: string, options: [], range: NSMakeRange(0, string.count)) { (result, flags, stop) in
//            guard let range = result?.range else {
//                return
//            }
//            let match = (string as NSString).substring(with: range)
//            var tokens = match.components(separatedBy: " ")
//            tokens.removeFirst()
//            block(tokens)
//        }
//    }
//}
