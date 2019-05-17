//
//  KeychainService.swift
//  eduVPN
//
//  Created by Johan Kool on 06/06/2018.
//  Copyright © 2017-2019 Commons Conservancy.
//

import Foundation
import Security

class KeychainService {
    
    enum Error: Swift.Error, LocalizedError {
        case unknown
        case unknownCommonName(String)
        case importError(Int32)
        case privateKeyError(Int32)
        case unsupportedAlgorithm
        case signingFailed
        case certificateReadFailed
        case passwordEncoding
        case updatePassword(OSStatus)
        case removePassword(OSStatus)
        case savePassword(OSStatus)
        case loadPassword(OSStatus)
        
        var errorDescription: String? {
            switch self {
            case .unknownCommonName(let commonName):
                return NSLocalizedString("No certificate with common name \"\(commonName)\" found", comment: "")
            case .importError(let osstatus):
                return NSLocalizedString("An import error occurred \(osstatus)", comment: "")
            case .privateKeyError(let osstatus):
                return NSLocalizedString("Private key error occurred \(osstatus)", comment: "")
            case .unsupportedAlgorithm:
                return NSLocalizedString("The requested key algorithm is not supported", comment: "")
            case .signingFailed:
                return NSLocalizedString("Failed to fulfill sign request", comment: "")
            case .certificateReadFailed:
                return NSLocalizedString("Failed to read certificate", comment: "")
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
            case .unknownCommonName:
                return NSLocalizedString("Add the missing certificate to your keychain.", comment: "")
            case .importError, .passwordEncoding, .privateKeyError:
                return NSLocalizedString("Try again.", comment: "")
            case .unsupportedAlgorithm:
                return NSLocalizedString("Check for app updates.", comment: "")
            case .signingFailed, .certificateReadFailed:
                return NSLocalizedString("Try again.", comment: "")
            case .updatePassword(let status), .removePassword(let status), .savePassword(let status), .loadPassword(let status):
                if let message = SecCopyErrorMessageString(status, nil) as String? {
                    return message
                } else {
                    return NSLocalizedString("Try again.", comment: "")
                }
            default:
                return NSLocalizedString("Try again later.", comment: "")
            }
        }
    }
    
    // MARK: - Credentials
    
    func importKeyPair(data: Data, passphrase: String) throws -> String {
        let options: NSDictionary = [kSecImportExportPassphrase: passphrase]
        
        var items : CFArray?
        
        let importError = SecPKCS12Import(data as CFData, options, &items)
        guard importError == noErr else {
            throw Error.importError(importError)
        }
        
        let theArray: CFArray = items!
        guard CFArrayGetCount(theArray) > 0 else {
            throw Error.importError(errSecInternalError)
        }
        
        let newArray = theArray as [AnyObject] as NSArray
        let dictionary = newArray.object(at: 0)
        let secIdentity = (dictionary as AnyObject)[kSecImportItemIdentity as String] as! SecIdentity
        
        return try commonName(for: secIdentity)
    }
    
    func removeIdentity(for commonName: String) throws {
        // TODO: This removes the public key, yet the certificate remains, however repeating this query with kSecClassCertificate gives errSecItemNotFound
        let query: NSDictionary = [kSecClass: kSecClassIdentity, kSecMatchSubjectWholeString: commonName]
        let queryError = SecItemDelete(query)
        guard queryError == noErr else {
            throw Error.unknownCommonName(commonName)
        }
    }
    
    private func identity(for commonName: String) throws -> SecIdentity {
        var secureItemValue: AnyObject? = nil
        let query: NSDictionary = [kSecClass: kSecClassIdentity, kSecMatchSubjectWholeString: commonName]
        let queryError = SecItemCopyMatching(query, &secureItemValue)
        guard queryError == noErr else {
            throw Error.unknownCommonName(commonName)
        }
        return secureItemValue as! SecIdentity
    }
    
    func certificate(for commonName: String) throws -> Data {
        let secIdentity = try identity(for: commonName)
        return try certificate(for: secIdentity)
    }
    
    func certificate(for secIdentity: SecIdentity) throws -> Data {
        var certificateRef: SecCertificate? = nil
        let securityError = SecIdentityCopyCertificate(secIdentity , &certificateRef)
        if securityError != noErr {
            certificateRef = nil
        }
        
        let dataOut = SecCertificateCopyData(certificateRef!)
        return dataOut as Data
    }
    
    func commonName(for secIdentity: SecIdentity) throws -> String {
        var certificateRef: SecCertificate? = nil
        let certificateError = SecIdentityCopyCertificate(secIdentity, &certificateRef)
        guard certificateError == noErr else {
            throw Error.certificateReadFailed
        }
        
        var commonName: CFString? = nil
        let commonNameError = SecCertificateCopyCommonName(certificateRef!, &commonName)
        guard commonNameError == noErr else {
            throw Error.certificateReadFailed
        }
        return commonName! as String
    }
    
    func sign(using commonName: String, dataToSign: Data) throws -> Data {
        let secIdentity = try identity(for: commonName)
        
        var secKey: SecKey? = nil
        let privateKeyError = SecIdentityCopyPrivateKey(secIdentity, &secKey)
        guard privateKeyError == noErr else {
            throw Error.privateKeyError(privateKeyError)
        }
        
        let algorithm: SecKeyAlgorithm = .rsaSignatureDigestPKCS1v15Raw

        guard SecKeyIsAlgorithmSupported(secKey!, .sign, algorithm) else {
            throw Error.unsupportedAlgorithm
        }
       
        var error: Unmanaged<CFError>? = nil
        guard let signature = SecKeyCreateSignature(secKey!, algorithm, dataToSign as CFData, &error) else {
            if let error = error?.takeUnretainedValue() {
                throw error
            }
            throw Error.signingFailed
        }

        return signature as Data
    }
    
    // MARK: - Passwords
    
    func updatePassword(service: String, account: String, password: String) throws {
        guard let data = password.data(using: .utf8) else {
            throw Error.passwordEncoding
        }

        let keychainQuery: NSDictionary = [kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: account, kSecReturnData: kCFBooleanTrue, kSecMatchLimit: kSecMatchLimitOne]
        
        let status = SecItemUpdate(keychainQuery as CFDictionary, [kSecValueData: data] as CFDictionary)
        guard status == noErr else {
            throw Error.updatePassword(status)
        }
    }
    
    func removePassword(service: String, account: String) throws {
        let keychainQuery: NSDictionary = [kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: account, kSecReturnData: kCFBooleanTrue, kSecMatchLimit: kSecMatchLimitOne]
        
        // Delete any existing items
        let status = SecItemDelete(keychainQuery as CFDictionary)
        guard status == noErr else {
            throw Error.removePassword(status)
        }
    }
    
    func savePassword(service: String, account: String, password: String) throws {
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
    
    func loadPassword(service: String, account: String) throws -> String? {
        let keychainQuery: NSDictionary = [kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: account, kSecReturnData: kCFBooleanTrue, kSecMatchLimit: kSecMatchLimitOne]
        
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
