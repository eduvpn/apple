//
//  SignatureHelper.swift
//  EduVPN
//
//  SignatureHelper: Helper to verify minisign signatures.
//

import Foundation
import libsodium
import CryptoKit

enum SignatureHelperError: LocalizedError {
    case signatureFetchFailed
    case invalidPublicKey
    case invalidSignature
    case publicKeyIdMismatch
    case unsupportedAlgorithm
    case legacySignatureNotAllowed
    case invalid
    
    var errorDescription: String? {
        switch self {
        case .signatureFetchFailed:
            return NSLocalizedString(
                "Fetching signature failed.",
                comment: "error message")
        case .invalidPublicKey:
            return NSLocalizedString(
                "Invalid public key",
                comment: "error message")
        case .invalidSignature:
            return NSLocalizedString(
                "Invalid signature",
                comment: "error message")
        case .publicKeyIdMismatch:
            return NSLocalizedString(
                "Public key id mismatch",
                comment: "error message")
        case .unsupportedAlgorithm:
            return NSLocalizedString(
                "Unsupported algorithm.",
                comment: "error message")
        case .legacySignatureNotAllowed:
            return NSLocalizedString(
                "Legacy minisign signature is not allowed",
                comment: "error message")
        case .invalid:
            return NSLocalizedString("Signature was invalid.", comment: "")
        }
    }
}

struct SignatureHelper {

    static var isLegacySignatureAllowed = true

    static func minisignSignatureFromFile(data: Data) throws -> Data {
        if let signatureFileContent = String(data: data, encoding: .utf8) {
            let lines = signatureFileContent.split(separator: "\n")
            if lines.indices.contains(1) {
                let signatureString = lines[1]
                if let signatureData = signatureString.data(using: .utf8), let signatureDataDecoded = Data(base64Encoded: signatureData) {
                    return signatureDataDecoded
                }
            }
        }
        throw SignatureHelperError.signatureFetchFailed
    }
    
    static func verify(signatureWithMetadata: Data, data: Data, publicKeyWithMetadata: Data) throws {
        guard publicKeyWithMetadata.count == 42 else {
            throw SignatureHelperError.invalidPublicKey
        }
        
        guard signatureWithMetadata.count == 74 else {
            throw SignatureHelperError.invalidSignature
        }
        
        guard publicKeyWithMetadata.subdata(in: 2..<10) == signatureWithMetadata.subdata(in: 2..<10) else {
            throw SignatureHelperError.publicKeyIdMismatch
        }

        let signatureAlgorithmId = String(data: signatureWithMetadata.subdata(in: 0..<2), encoding: .utf8)
        guard signatureAlgorithmId == "Ed" || signatureAlgorithmId == "ED" else {
            throw SignatureHelperError.unsupportedAlgorithm
        }

        let isPreHashed: Bool = (signatureAlgorithmId == "ED")

        guard isLegacySignatureAllowed || isPreHashed else {
            throw SignatureHelperError.legacySignatureNotAllowed
        }

        let publicKey = publicKeyWithMetadata.subdata(in: 10..<42)
        let signature = signatureWithMetadata.subdata(in: 10..<74)
        
        let isVerified: Bool = self.verify(message: Array(data),
                                           publicKey: Array(publicKey),
                                           signature: Array(signature),
                                           isPreHashed: isPreHashed)

        guard isVerified else {
            throw SignatureHelperError.invalid
        }
    }

    static func isSignatureValid(data: Data, signatureWithMetadata: Data,
                                 publicKeyWithMetadata: Data) -> Bool {
        do {
            try verify(signatureWithMetadata: signatureWithMetadata, data: data,
                       publicKeyWithMetadata: publicKeyWithMetadata)
        } catch {
            return false
        }
        return true
    }

    private typealias Bytes = [UInt8]
    
    private static func verify(message: Bytes, publicKey: Bytes, signature: Bytes, isPreHashed: Bool) -> Bool {
        guard publicKey.count == 32 else {
            return false
        }

        let data: Bytes = {
            if isPreHashed {
                let hashLength = Int(crypto_generichash_BYTES_MAX)
                var hash = Bytes(repeating: 0, count: hashLength)
                crypto_generichash(&hash, hashLength, message, UInt64(message.count), [], 0)
                return hash
            } else {
                return message
            }
        }()

        if #available(iOS 13.0, macOS 10.15, *) {
            // Use CryptoKit
            do {
                let cryptoKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicKey)
                return cryptoKey.isValidSignature(signature, for: data)
            } catch {
                return false
            }
        } else {
            // Use libsodium
            return 0 == crypto_sign_verify_detached(signature,
                                                    data,
                                                    UInt64(data.count),
                                                    publicKey)
        }
    }
    
}
