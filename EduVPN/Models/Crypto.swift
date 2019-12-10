//
//  Crypto.swift
//  EduVPN
//
//  Created by Jeroen Leenarts on 24/07/2019.
//  Copyright © 2019 SURFNet. All rights reserved.
//

import Foundation
import os.log

enum CryptoError: Error {
    case keyCreationFailed
}

class Crypto {
    
    static var shared: Crypto {
        return self.sharedInstance
    }
    
    private static let sharedInstance = Crypto()
    
    private let keyName = "disk_storage_key"
    
    private let hasSecurityEnclave: Bool
    private let algorithm: SecKeyAlgorithm
    private let keySize: Int
    private let keyType: CFString
    
    init() {
        var attributes = [String: Any]()
        attributes[kSecAttrKeyType as String] = kSecAttrKeyTypeEC
        attributes[kSecAttrKeySizeInBits as String] = 256
        attributes[kSecAttrTokenID as String] = kSecAttrTokenIDSecureEnclave
        
        var error: Unmanaged<CFError>?
        let randomKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error)
        
        if randomKey != nil {
            self.hasSecurityEnclave = true
            self.keySize = 256
            self.keyType = kSecAttrKeyTypeEC
            self.algorithm = .eciesEncryptionCofactorVariableIVX963SHA256AESGCM
        } else {
            self.hasSecurityEnclave = false
            self.keySize = 4096
            self.keyType = kSecAttrKeyTypeRSA
            self.algorithm = .rsaEncryptionOAEPSHA512AESGCM
        }
    }
    
    private func makeAndStoreKey(name: String) throws -> SecKey {
        
        // TODO: Check when this flag is appropriate
        guard let access =
            SecAccessControlCreateWithFlags(kCFAllocatorDefault,
                                            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                                            [], // SecAccessControlCreateFlags.privateKeyUsage,
                                            nil) else {
                                                throw CryptoError.keyCreationFailed
        }
        var attributes = [String: Any]()
        attributes[kSecAttrKeyType as String] = self.keyType
        attributes[kSecAttrKeySizeInBits as String] = self.keySize
        #if targetEnvironment(simulator)
        print("SIMULATOR does not support secure enclave.")
        #else
        if self.hasSecurityEnclave {
            attributes[kSecAttrTokenID as String] = kSecAttrTokenIDSecureEnclave
        }
        #endif

        let tag = name //.data(using: .utf8)!
        attributes[kSecPrivateKeyAttrs as String] = [
            kSecAttrIsPermanent as String: true,
            kSecAttrApplicationTag as String: tag,
            kSecAttrAccessControl as String: access
        ]

        var error: Unmanaged<CFError>?
        let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error)

        if let error = error {
            throw error.takeRetainedValue() as Error
        }

        guard let unwrappedPrivateKey = privateKey else {
            throw CryptoError.keyCreationFailed
        }

        return unwrappedPrivateKey
    }

    private func loadKey(name: String) -> SecKey? {
        let tag = name
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecAttrKeyType as String: self.keyType,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
            kSecReturnRef as String: true
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else {
            return nil
        }
        return (item as! SecKey) // swiftlint:disable:this force_cast
    }

    func encrypt(data clearTextData: Data) throws -> Data? {
        let key = try loadKey(name: keyName) ?? makeAndStoreKey(name: keyName)

        guard let publicKey = SecKeyCopyPublicKey(key) else {
            // Can't get public key
            return nil
        }
        let algorithm: SecKeyAlgorithm = self.algorithm
        guard SecKeyIsAlgorithmSupported(publicKey, .encrypt, algorithm) else {
            os_log("Can't encrypt. Algorithm not supported.", log: Log.crypto, type: .error)
            return nil
        }
        var error: Unmanaged<CFError>?
        let cipherTextData = SecKeyCreateEncryptedData(publicKey, algorithm,
                                                       clearTextData as CFData,
                                                       &error) as Data?
        if let error = error {
            os_log("Can't encrypt. %{public}@", log: Log.crypto, type: .error, (error.takeRetainedValue() as Error).localizedDescription)
            return nil
        }
        guard cipherTextData != nil else {
            os_log("Can't encrypt. No resulting cipherTextData", log: Log.crypto, type: .error)
            return nil
        }

        os_log("Encrypted data.", log: Log.crypto, type: .info)
        return cipherTextData
    }

    func decrypt(data cipherTextData: Data) -> Data? {
        guard let key = loadKey(name: keyName) else { return nil }

        let algorithm: SecKeyAlgorithm = self.algorithm
        guard SecKeyIsAlgorithmSupported(key, .decrypt, algorithm) else {
            os_log("Can't decrypt. Algorithm not supported.", log: Log.crypto, type: .error)
            return nil
        }

        var error: Unmanaged<CFError>?
        let clearTextData = SecKeyCreateDecryptedData(key,
                                                      algorithm,
                                                      cipherTextData as CFData,
                                                      &error) as Data?
        if let error = error {
            os_log("Can't decrypt. %{public}@", log: Log.crypto, type: .error, (error.takeRetainedValue() as Error).localizedDescription)
            return nil
        }
        guard clearTextData != nil else {
            os_log("Can't decrypt. No resulting cleartextData.", log: Log.crypto, type: .error)
            return nil
        }
        os_log("Decrypted data.", log: Log.crypto, type: .info)
        return clearTextData
    }
}
