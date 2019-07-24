//
//  Crypto.swift
//  EduVPN
//
//  Created by Jeroen Leenarts on 24/07/2019.
//  Copyright © 2019 SURFNet. All rights reserved.
//

import Foundation

class Crypto {
    private static let keyName = "disk_storage_key"

    private static func makeAndStoreKey(name: String) throws -> SecKey {
        let flags: SecAccessControlCreateFlags = .privateKeyUsage
        let access =
            SecAccessControlCreateWithFlags(kCFAllocatorDefault,
                                            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                                            flags,
                                            nil)!
        let tag = name.data(using: .utf8)!
        #if targetEnvironment(simulator)
        let attributes: [String: Any] = [
            kSecAttrKeyType as String           : kSecAttrKeyTypeEC,
            kSecAttrKeySizeInBits as String     : 256,
            //            kSecAttrTokenID as String           : kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs as String : [
                kSecAttrCanDecrypt as String        : true,
                kSecAttrIsPermanent as String       : true,
                kSecAttrApplicationTag as String    : tag,
                kSecAttrAccessControl as String     : access
            ]
        ]
        #else
        let attributes: [String: Any] = [
            kSecAttrKeyType as String           : kSecAttrKeyTypeEC,
            kSecAttrKeySizeInBits as String     : 256,
            kSecAttrTokenID as String           : kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs as String : [
                kSecAttrCanDecrypt as String        : true,
                kSecAttrIsPermanent as String       : true,
                kSecAttrApplicationTag as String    : tag,
                kSecAttrAccessControl as String     : access
            ]
        ]
        #endif

        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw error!.takeRetainedValue() as Error
        }

        return privateKey
    }

    private static func loadKey(name: String) -> SecKey? {
        let tag = name.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String                 : kSecClassKey,
            kSecAttrApplicationTag as String    : tag,
            kSecAttrKeyType as String           : kSecAttrKeyTypeEC,
            kSecReturnRef as String             : true
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else {
            return nil
        }
        return (item as! SecKey)
    }

    static func encrypt(data clearTextData: Data) throws -> Data? {
        let key = try loadKey(name: keyName) ?? makeAndStoreKey(name: keyName)

        guard let publicKey = SecKeyCopyPublicKey(key) else {
            // Can't get public key
            return nil
        }
        let algorithm: SecKeyAlgorithm = .eciesEncryptionCofactorVariableIVX963SHA256AESGCM
        guard SecKeyIsAlgorithmSupported(publicKey, .encrypt, algorithm) else {
            //TODO log error
            //            UIAlertController.showSimple(title: "Can't encrypt",
            //                                         text: "Algorith not supported", from: self)
            return nil
        }
        var error: Unmanaged<CFError>?
        let cipherTextData = SecKeyCreateEncryptedData(publicKey, algorithm,
                                                       clearTextData as CFData,
                                                       &error) as Data?
        guard cipherTextData != nil else {
            // TODO log error
            //            UIAlertController.showSimple(title: "Can't encrypt",
            //                                         text: (error!.takeRetainedValue() as Error).localizedDescription,
            //                                         from: self)
            return nil
        }

        return cipherTextData
    }

    static func decrypt(data cipherTextData: Data) -> Data? {
        guard let key = loadKey(name: keyName) else { return nil }

        let algorithm: SecKeyAlgorithm = .eciesEncryptionCofactorVariableIVX963SHA256AESGCM
        guard SecKeyIsAlgorithmSupported(key, .decrypt, algorithm) else {
            //TODO log error
            //            UIAlertController.showSimple(title: "Can't decrypt",
            //                                         text: "Algorith not supported", from: self)
            return nil
        }

        // SecKeyCreateDecryptedData call is blocking when the used key
        // is protected by biometry authentication. If that's not the case,
        // dispatching to a background thread isn't necessary.
        var error: Unmanaged<CFError>?
        let clearTextData = SecKeyCreateDecryptedData(key,
                                                      algorithm,
                                                      cipherTextData as CFData,
                                                      &error) as Data?
        guard clearTextData != nil else {
            //TODO log error
            //                    UIAlertController.showSimple(title: "Can't decrypt",
            //                                                 text: (error!.takeRetainedValue() as Error).localizedDescription,
            //                                                 from: self)
            return nil
        }
        return clearTextData
    }
}
