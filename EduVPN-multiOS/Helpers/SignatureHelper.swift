//
//  SignatureHelper.swift
//  EduVPN
//
//  Created by Johan Kool on 10/04/2020.
//  Copyright © 2020 SURFNet. All rights reserved.
//

import Foundation
import libsodium
import CryptoKit

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
        throw AppCoordinatorError.minisignSignatureFetchFailed
    }
    
    static func verify(signatureWithMetadata: Data, data: Data) throws {
        guard let publicKeyWithMetadata = StaticService.publicKey else {
            throw AppCoordinatorError.minisignatureVerifyMissingPublicKey
        }
        
        guard publicKeyWithMetadata.count == 42 else {
            throw AppCoordinatorError.minisignatureVerifyInvalidPublicKey
        }
        
        guard signatureWithMetadata.count == 74 else {
            throw AppCoordinatorError.minisignatureVerifyInvalidSignature
        }
        
        guard publicKeyWithMetadata.subdata(in: 0..<10) == signatureWithMetadata.subdata(in: 0..<10) else {
            throw AppCoordinatorError.minisignatureVerifyPublicKeySignatureMismatch
        }
        
        guard publicKeyWithMetadata.subdata(in: 0..<2) == "Ed".data(using: .utf8) else {
            throw AppCoordinatorError.minisignatureVerifyUnsupportedAlgorithm
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
            throw AppCoordinatorError.minisignatureVerifyInvalid
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
