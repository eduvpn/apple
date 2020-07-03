//
//  SignatureHelper.swift
//  EduVPN
//
//  Created by Johan Kool on 10/04/2020.
//

import Foundation
import libsodium
import CryptoKit

enum SignatureHelperError: LocalizedError {
    case signatureFetchFailed
    case invalidPublicKey
    case invalidSignature
    case publicKeySignatureMismatch
    case unsupportedAlgorithm
    case invalid
    
    var errorDescription: String? {
        switch self {
        case .signatureFetchFailed:
            return NSLocalizedString("Fetching signature failed.", comment: "")
        case .invalidPublicKey:
            return NSLocalizedString("Invalid public key", comment: "")
        case .invalidSignature:
            return NSLocalizedString("Invalid signature", comment: "")
        case .publicKeySignatureMismatch:
            return NSLocalizedString("Public key and signature mismatch", comment: "")
        case .unsupportedAlgorithm:
            return NSLocalizedString("Unsupported algorithm.", comment: "")
        case .invalid:
            return NSLocalizedString("Signature was invalid.", comment: "")
        }
    }
}

struct SignatureHelper {
    
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
        
        guard publicKeyWithMetadata.subdata(in: 0..<10) == signatureWithMetadata.subdata(in: 0..<10) else {
            throw SignatureHelperError.publicKeySignatureMismatch
        }
        
        guard publicKeyWithMetadata.subdata(in: 0..<2) == "Ed".data(using: .utf8) else {
            throw SignatureHelperError.unsupportedAlgorithm
        }
        
        let publicKey = publicKeyWithMetadata.subdata(in: 10..<42)
        let signature = signatureWithMetadata.subdata(in: 10..<74)
        
        let isVerified: Bool
        
        if #available(iOS 13.0, macOS 10.15, *) {
            let cryptoKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicKey)
            isVerified = cryptoKey.isValidSignature(signature, for: data)
        } else {
            isVerified = self.verify(message: Array(data),
                                     publicKey: Array(publicKey),
                                     signature: Array(signature))
        }
        
        guard isVerified else {
            throw SignatureHelperError.invalid
        }
    }
    
    private typealias Bytes = [UInt8]
    
    private static func verify(message: Bytes, publicKey: Bytes, signature: Bytes) -> Bool {
        guard publicKey.count == 32 else {
            return false
        }
        
        return 0 == crypto_sign_verify_detached(signature,
                                                message,
                                                UInt64(message.count),
                                                publicKey)
    }
    
}
