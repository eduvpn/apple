//
//  KeychainService.swift
//  EduVPN
//
//  Created by Jeroen Leenarts on 28/05/2019.
//  Based on KeychainService created by Johan Kool on 06/06/2018.
//
//  Copyright © 2017-2019 Commons Conservancy.
//

import Foundation
import Security

class KeychainService {

    enum Error: Swift.Error, LocalizedError {
        case unknown
        case passwordEncoding
        case updatePassword(OSStatus)
        case removePassword(OSStatus)
        case savePassword(OSStatus)
        case loadPassword(OSStatus)

        var errorDescription: String? {
            switch self {
            case .passwordEncoding:
                return NSLocalizedString("Failed to encode password", comment: "")
            case .updatePassword:
                return NSLocalizedString("Failed to update password", comment: "")
            case .removePassword:
                return NSLocalizedString("Failed to remove password", comment: "")
            case .savePassword:
                return NSLocalizedString("Failed to save password", comment: "")
            case .loadPassword:
                return NSLocalizedString("Failed to read password", comment: "")
            default:
                return NSLocalizedString("An unknown error occurred", comment: "")
            }
        }

        var recoverySuggestion: String? {
            switch self {
            case .passwordEncoding:
                return NSLocalizedString("Try again.", comment: "")
            case .updatePassword(let status), .removePassword(let status), .savePassword(let status), .loadPassword(let status):
                if #available(iOS 11.3, *) {
                    if let message = SecCopyErrorMessageString(status, nil) as String? {
                        return message
                    }
                }
                return NSLocalizedString("Try again.", comment: "")

            default:
                return NSLocalizedString("Try again later.", comment: "")
            }
        }
    }

    // MARK: - Certificates

    static func saveCertificate(label: String, certificateString: String) throws {
        guard let data = certificateString.data(using: .ascii) else {
            throw Error.passwordEncoding
        }

        guard let derData = decodeToDER(pem: data) else {
            throw Error.passwordEncoding
        }

        guard let certificate = SecCertificateCreateWithData(nil, derData as CFData) else {
            throw Error.passwordEncoding
        }

        let keychainQuery = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrLabel as String: label,
            kSecValueRef as String: certificate] as CFDictionary

        // Add the new keychain item
        let status = SecItemAdd(keychainQuery as CFDictionary, nil)
        guard status == noErr else {
            throw Error.savePassword(status)
        }
    }

    static func loadCertificate(label: String) throws -> SecCertificate? {
        let keychainQuery = [
            kSecClass: kSecClassCertificate,
            kSecAttrLabel: label,
            kSecReturnRef: true, //kCFBooleanTrue,
            ] as CFDictionary

        var dataTypeRef: CFTypeRef?

        // Search for the keychain certificate
        let status = SecItemCopyMatching(keychainQuery, &dataTypeRef)
        guard status == noErr else {
            throw Error.loadPassword(status)
        }

        let certificate = dataTypeRef as! SecCertificate

        return certificate
    }

    static public func decodeToDER(pem pemData: Data) -> Data? {

        let beginPemBlock = "-----BEGIN CERTIFICATE-----"
        let endPemBlock   = "-----END CERTIFICATE-----"

        if let pem = String(data: pemData, encoding: .ascii),
            pem.contains(beginPemBlock) {

            let lines = pem.components(separatedBy: .newlines)
            var base64buffer  = ""
            var certLine = false
            for line in lines {
                if line == endPemBlock {
                    certLine = false
                }
                if certLine {
                    base64buffer.append(line)
                }
                if line == beginPemBlock {
                    certLine = true
                }
            }
            if let derDataDecoded = Data(base64Encoded: base64buffer) {
                return derDataDecoded
            }
        }

        return nil
    }

    // MARK: - Passwords

    static func updatePassword(service: String, account: String, password: String) throws {
        guard let data = password.data(using: .utf8) else {
            throw Error.passwordEncoding
        }

        let keychainQuery = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true, //kCFBooleanTrue,
            kSecMatchLimit: kSecMatchLimitOne] as CFDictionary

        let status = SecItemUpdate(keychainQuery, [kSecValueData: data] as CFDictionary)
        guard status == noErr else {
            throw Error.updatePassword(status)
        }
    }

    static func removePassword(service: String, account: String) throws {
        let keychainQuery = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true, //kCFBooleanTrue,
            kSecMatchLimit as String: kSecMatchLimitOne
            ] as CFDictionary

        // Delete any existing items
        let status = SecItemDelete(keychainQuery)
        guard status == noErr else {
            throw Error.removePassword(status)
        }
    }

    static func savePassword(service: String, account: String, password: String) throws {
        guard let data = password.data(using: .utf8) else {
            throw Error.passwordEncoding
        }

        let keychainQuery: NSDictionary = [kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: account, kSecValueData: data]

        // Add the new keychain item
        let status = SecItemAdd(keychainQuery as CFDictionary, nil)
        guard status == noErr else {
            throw Error.savePassword(status)
        }
    }

    static func loadPassword(service: String, account: String) throws -> String? {
        let keychainQuery = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true, //kCFBooleanTrue,
            kSecMatchLimit: kSecMatchLimitOne] as CFDictionary

        var dataTypeRef: AnyObject?

        // Search for the keychain items
        let status = SecItemCopyMatching(keychainQuery, &dataTypeRef)
        guard status == noErr else {
            throw Error.loadPassword(status)
        }

        guard let retrievedData = dataTypeRef as? Data else {
            return nil
        }

        guard let contentsOfKeychain = String(data: retrievedData, encoding: .utf8) else {
            throw Error.passwordEncoding
        }

        return contentsOfKeychain
    }
}
