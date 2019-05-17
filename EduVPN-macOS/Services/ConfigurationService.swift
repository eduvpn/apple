//
//  ConfigurationService.swift
//  eduVPN
//
//  Created by Johan Kool on 06/07/2017.
//  Copyright © 2017-2019 Commons Conservancy.
//

import Foundation
import AppAuth

/// Fetches configuration
class ConfigurationService {
    
    enum Error: Swift.Error, LocalizedError {
        case unknown
        case invalidURL
        case missingToken
        case invalidKeyPair
        case invalidConfiguration
        case certificateCheckFailed
        case certificateMissing // CN never exist, was deleted by the user, or the server was reinstalled and the certificate is no longer there
        case userIsDisabled // The user account was disabled by an administrator
        case certificateNotYetValid // The certificate is not yet valid
        case certificateExpired // The certificate is no longer valid (expired)
        
        var errorDescription: String? {
            switch self {
            case .unknown:
                return NSLocalizedString("Configuration failed for unknown reason", comment: "")
            case .invalidURL:
                return NSLocalizedString("Configuration failed because provider info was invalid", comment: "")
            case .missingToken:
                return NSLocalizedString("Configuration could not be retrieved because no valid token was available", comment: "")
            case .invalidKeyPair:
                return NSLocalizedString("Invalid keypair received from provider", comment: "")
            case .invalidConfiguration:
                return NSLocalizedString("Invalid configuration received from provider", comment: "")
            case .certificateCheckFailed:
                return NSLocalizedString("Could not check certificate", comment: "")
            case .certificateMissing:
                return NSLocalizedString("No certificate available", comment: "")
            case .userIsDisabled:
                return NSLocalizedString("This user account is disabled", comment: "")
            case .certificateNotYetValid:
                return NSLocalizedString("The certificate is not yet valid", comment: "")
            case .certificateExpired:
                return NSLocalizedString("The certificate is no longer valid", comment: "")
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .unknown:
                return NSLocalizedString("Try to connect again.", comment: "")
            case .invalidURL:
                return NSLocalizedString("Go back to the first screen and try again.", comment: "")
            case .missingToken:
                return NSLocalizedString("Try to authorize again with your provider.", comment: "")
            case .invalidKeyPair:
                return NSLocalizedString("Try to connect again later.", comment: "")
            case .invalidConfiguration:
                return NSLocalizedString("Try to connect again later.", comment: "")
            case .certificateCheckFailed:
                return NSLocalizedString("Try to connect again.", comment: "")
            case .certificateMissing:
                return NSLocalizedString("Try to connect again.", comment: "")
            case .userIsDisabled:
                return NSLocalizedString("Contact your administrator for further details", comment: "")
            case .certificateNotYetValid:
                return NSLocalizedString("Try to connect again.", comment: "")
            case .certificateExpired:
                return NSLocalizedString("Try to connect again.", comment: "")
            }
        }
    }
    
    private let urlSession: URLSession
    private let authenticationService: AuthenticationService
    private let keychainService: KeychainService
    
    init(urlSession: URLSession, authenticationService: AuthenticationService, keychainService: KeychainService) {
        self.urlSession = urlSession
        self.authenticationService = authenticationService
        self.keychainService = keychainService
    }
    
    /// Fetches configuration for a profile including certificate and private key
    ///
    /// - Parameters:
    ///   - profile: Profile
    ///   - handler: Config or error
    func configure(for profile: Profile, handler: @escaping (Result<(config: Config, certificateCommonName: String)>) -> ()) {
        restoreOrCreateKeyPair(for: profile.info) { (result) in
            switch result {
            case .success(let certificateCommonName):
                self.fetchConfig(for: profile) { (result) in
                    switch result {
                    case .success(let config):
                        handler(.success((config: config, certificateCommonName: certificateCommonName)))
                    case .failure(let error):
                        handler(.failure(error))
                    }
                }
            case .failure(let error):
                handler(.failure(error))
            }
        }
    }
    
    /// Checks if keypair is available for provider, otherwise creates and stores new keypair
    ///
    /// - Parameters:
    ///   - info: Provider info
    ///   - handler: Certificate common name or error
    private func restoreOrCreateKeyPair(for info: ProviderInfo, handler: @escaping (Result<String>) -> ()) {
        guard info.provider.connectionType != .localConfig else {
            handler(.success(info.provider.publicKey ?? ""))
            return
        }

        
        var keyPairs = UserDefaults.standard.array(forKey: .keyPairs) ?? []
        
        let certificateCommonNames = keyPairs.lazy.compactMap { keyPair -> String? in
            guard let keyPair = keyPair as? [String: AnyObject] else {
                return nil
            }
            
            guard let providerBaseURL = keyPair["providerBaseURL"] as? String, info.provider.baseURL.absoluteString == providerBaseURL else {
                return nil
            }
            
            guard let certificateCommonName = keyPair["certificateCommonName"] as? String else {
                return nil
            }
            
            return certificateCommonName
        }
        
        let createKeyPair: () -> () = {
            self.createKeyPair(for: info) { result in
                switch result {
                case .success((let certificate, let privateKey)):
                    // To use ovpn config file with Tunnelblick, use the output of the line below
                    // debugLog( "<<config here>" + "\n<cert>\n" + certificate + "\n</cert>\n<key>\n" + privateKey + "\n</key>")
                    
                    let passphrase = String.random()
                    self.createPKCS12(certificate: certificate, privateKey: privateKey, passphrase: passphrase, friendlyName: info.provider.baseURL.absoluteString) { result in
                        switch result {
                        case .success(let data):
                            do {
                                let certificateCommonName = try self.keychainService.importKeyPair(data: data, passphrase: passphrase)
                                
                                let keyPair = ["provider": info.provider.displayName, "providerBaseURL": info.provider.baseURL.absoluteString, "certificateCommonName": certificateCommonName]
                                keyPairs.append(keyPair)
                                UserDefaults.standard.set(keyPairs, forKey: .keyPairs)
                                handler(.success(certificateCommonName))
                            } catch {
                                handler(.failure(error))
                            }
                        case .failure(let error):
                            handler(.failure(error))
                        }
                    }
                case .failure(let error):
                    handler(.failure(error))
                }
            }
        }
        

        
        if let certificateCommonName = certificateCommonNames.first {
            // Check if still valid
            checkCertificate(for: info, certificateCommonName: certificateCommonName) { result in
                switch result {
                case .success:
                    handler(.success(certificateCommonName))
                case .failure(let error):
                    // Certain errors -> create new keypair
                    switch error {
                    case Error.certificateNotYetValid, Error.certificateExpired, Error.certificateMissing:
                        self.forgetKeyPair(certificateCommonName: certificateCommonName)
                        createKeyPair()
                    case Error.userIsDisabled:
                        // Inform user
                        handler(.failure(error))
                    default:
                        handler(.failure(error))
                    }
                }
            }
        } else {
            // No key pair found, create new one and store it
            createKeyPair()
        }
    }
    
    private func forgetKeyPair(certificateCommonName: String) {
        try? keychainService.removeIdentity(for: certificateCommonName)
        
        var keyPairs = UserDefaults.standard.array(forKey: .keyPairs) ?? []
        keyPairs = keyPairs.filter { keyPair -> Bool in
            guard let keyPair = keyPair as? [String: AnyObject] else {
                return false
            }
            
            guard let currentCertificateCommonName = keyPair["certificateCommonName"] as? String else {
                return false
            }
            
            return currentCertificateCommonName != certificateCommonName
        }
        UserDefaults.standard.set(keyPairs, forKey: .keyPairs)
    }
    
    /// Lists common names for certificates used by provider
    ///
    /// - Parameters:
    ///   - provider: Provider
    /// - Returns: List of common names
    private func certificateCommonNames(for provider: Provider) -> [String] {
        guard provider.connectionType != .localConfig else {
            if let commonName = provider.publicKey {
                return [commonName]
            } else {
                return []
            }
        }
        
        let keyPairs = UserDefaults.standard.array(forKey: .keyPairs) ?? []
        
        let certificateCommonNames = keyPairs.compactMap { keyPair -> String? in
            guard let keyPair = keyPair as? [String: AnyObject] else {
                return nil
            }
            
            guard let providerBaseURL = keyPair["providerBaseURL"] as? String, provider.baseURL.absoluteString == providerBaseURL else {
                return nil
            }
            
            guard let certificateCommonName = keyPair["certificateCommonName"] as? String else {
                return nil
            }
            
            return certificateCommonName
        }
        
        return certificateCommonNames
    }

    /// Removes any known stored identities for a provider
    ///
    /// Does not delete selected certificate/identity for local configs, since that is under users control.
    ///
    /// - Parameter provider: Provider
    func removeIdentity(for provider: Provider) {
        guard provider.connectionType != .localConfig else {
            // Do NOT delete selected certificate/identity for local configs
            return
        }
        
        let commonNames = certificateCommonNames(for: provider)
        for commonName in commonNames {
            forgetKeyPair(certificateCommonName: commonName)
        }
    }
    
    /// Creates keypair with provider
    ///
    /// - Parameters:
    ///   - info: Provider info
    ///   - authenticationBehavior: Whether authentication should be retried when token is revoked or expired
    ///   - handler: Keypair or error
    private func createKeyPair(for info: ProviderInfo, authenticationBehavior: AuthenticationService.Behavior = .ifNeeded, handler: @escaping (Result<(certificate: String, privateKey: String)>) -> ()) {
        guard let url = URL(string: "create_keypair", relativeTo: info.apiBaseURL) else {
            handler(.failure(Error.invalidURL))
            return
        }
        
        authenticationService.performAction(for: info, authenticationBehavior: authenticationBehavior) { (accessToken, idToken, error) in
            guard let accessToken = accessToken else {
                handler(.failure(error ?? Error.missingToken))
                return
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
            let data = "display_name=eduVPN%20(macOS)".data(using: .utf8)!
            request.httpBody = data
            request.setValue("\(data.count)", forHTTPHeaderField: "Content-Length")
            
            let task = self.urlSession.dataTask(with: request) { (data, response, error) in
                guard let data = data, let response = response as? HTTPURLResponse else {
                    handler(.failure(error ?? Error.unknown))
                    return
                }
                
                guard response.statusCode != 401 else {
                    // Unauthorized! Try to authenticate again
                    self.createKeyPair(for: info, authenticationBehavior: .always, handler: handler)
                    return
                }
                
                guard 200..<300 ~= response.statusCode else {
                    handler(.failure(error ?? Error.unknown))
                    return
                }
                
                do {
                    guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? NSDictionary else {
                        handler(.failure(Error.invalidKeyPair))
                        return
                    }
                    
                    guard let certificate = json.value(forKeyPath: "create_keypair.data.certificate") as? String else {
                        handler(.failure(Error.invalidKeyPair))
                        return
                    }
                    
                    guard let privateKey = json.value(forKeyPath: "create_keypair.data.private_key") as? String else {
                        handler(.failure(Error.invalidKeyPair))
                        return
                    }
                    
                    handler(.success((certificate: certificate, privateKey: privateKey)))
                } catch(let error) {
                    handler(.failure(error))
                    return
                }
            }
            task.resume()
        }
    }
    
    /// Checks if a certificate is still valid
    ///
    /// - Parameters:
    ///   - info: Provider info
    ///   - certificateCommonName: Common name of the certificate
    ///   - authenticationBehavior: Whether authentication should be retried when token is revoked or expired
    ///   - handler: Void (valid) or an error
    private func checkCertificate(for info: ProviderInfo, certificateCommonName: String, authenticationBehavior: AuthenticationService.Behavior = .ifNeeded, handler: @escaping (Result<Void>) -> ()) {
        guard let bareURL = URL(string: "check_certificate", relativeTo: info.apiBaseURL) else {
            handler(.failure(Error.invalidURL))
            return
        }
        
        guard var urlComponents = URLComponents(url: bareURL, resolvingAgainstBaseURL: true) else {
            handler(.failure(Error.invalidURL))
            return
        }
        
        urlComponents.queryItems = [URLQueryItem(name: "common_name", value: certificateCommonName)]
        guard let url = urlComponents.url else {
            handler(.failure(Error.invalidURL))
            return
        }
        
        authenticationService.performAction(for: info, authenticationBehavior: authenticationBehavior) { (accessToken, idToken, error) in
            guard let accessToken = accessToken else {
                handler(.failure(error ?? Error.missingToken))
                return
            }
            var request = URLRequest(url: url)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            
            let task = self.urlSession.dataTask(with: request) { (data, response, error) in
                guard let data = data, let response = response as? HTTPURLResponse else {
                    handler(.failure(error ?? Error.unknown))
                    return
                }
                
                guard response.statusCode != 401 else {
                    // Unauthorized! Try to authenticate again
                    self.checkCertificate(for: info, certificateCommonName: certificateCommonName, authenticationBehavior: .always, handler: handler)
                    return
                }
                
                guard 200..<300 ~= response.statusCode else {
                    handler(.failure(error ?? Error.unknown))
                    return
                }
                
                do {
                    guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? NSDictionary else {
                        handler(.failure(Error.certificateCheckFailed))
                        return
                    }
                    
                    guard let isValid = json.value(forKeyPath: "check_certificate.data.is_valid") as? Bool else {
                        handler(.failure(Error.certificateCheckFailed))
                        return
                    }
                    
                    guard let reason = json.value(forKeyPath: "check_certificate.data.reason") as? String else {
                        if isValid {
                            handler(.success(Void()))
                        } else {
                            handler(.failure(Error.certificateCheckFailed))
                        }
                        return
                    }
                    
                    let error: Error
                    switch reason {
                    case "certificate_missing":
                        error = Error.certificateMissing
                    case "user_disabled":
                        error = Error.userIsDisabled
                    case "certificate_not_yet_valid":
                        error = Error.certificateNotYetValid
                    case "certificate_expired":
                        error = Error.certificateExpired
                    default:
                        error = Error.certificateCheckFailed
                    }
                    
                    handler(.failure(error))
                } catch {
                    handler(.failure(error))
                }
            }
            task.resume()
        }
    }
    
    /// Fetches config from provider
    ///
    /// - Parameters:
    ///   - profile: Profile
    ///   - authenticationBehavior: Whether authentication should be retried when token is revoked or expired
    ///   - handler: Config or error
    private func fetchConfig(for profile: Profile, authenticationBehavior: AuthenticationService.Behavior = .ifNeeded, handler: @escaping (Result<Config>) -> ()) {
        guard profile.info.provider.connectionType != .localConfig else {
            do {
                let config = try String(contentsOf: profile.info.provider.baseURL)
                handler(.success(config))
            }
            catch {
                handler(.failure(error))
            }
            return
        }
        
        guard let url = URL(string: "profile_config", relativeTo: profile.info.apiBaseURL) else {
            handler(.failure(Error.invalidURL))
            return
        }
        
        guard var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            handler(.failure(Error.invalidURL))
            return
        }
        
        var queryItems = urlComponents.queryItems ?? []
        queryItems.append(URLQueryItem(name: "profile_id", value: profile.profileId))
        urlComponents.queryItems = queryItems
        
        guard let requestUrl = urlComponents.url else {
            handler(.failure(Error.invalidURL))
            return
        }

        authenticationService.performAction(for: profile.info, authenticationBehavior: authenticationBehavior) { (accessToken, idToken, error) in
            guard let accessToken = accessToken else {
                handler(.failure(error ?? Error.missingToken))
                return
            }
            var request = URLRequest(url: requestUrl)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            
            let task = self.urlSession.dataTask(with: request) { (data, response, error) in
                guard let data = data, let response = response as? HTTPURLResponse else {
                    handler(.failure(error ?? Error.unknown))
                    return
                }
                
                guard response.statusCode != 401 else {
                    // Unauthorized! Try to authenticate again
                    self.fetchConfig(for: profile, authenticationBehavior: .always, handler: handler)
                    return
                }
                
                guard 200..<300 ~= response.statusCode else {
                    handler(.failure(error ?? Error.unknown))
                    return
                }
                
                guard let config = String(data: data, encoding: .utf8) else {
                    handler(.failure(Error.invalidConfiguration))
                    return
                }
                
                handler(.success(config))
            }
            task.resume()
        }
    }
    
    /// Creates a PKCS#12 file suitable for Keychain import
    ///
    /// - Parameters:
    ///   - certificate: Certificate as PEM string
    ///   - privateKey: Private key as PEM string
    ///   - passphrase: Passphrase to set on PKCS#12 file
    ///   - friendlyName: String containing the "BaseURL"
    ///   - handler: PKCS#12 file as data or error
    func createPKCS12(certificate: String, privateKey: String, passphrase: String, friendlyName: String, handler: @escaping ((Result<Data>) -> ())) {
        do {
            let process = Process()
            process.launchPath = "/usr/bin/openssl"
            
            let inkeyPath = try temporaryPath(for: "key.pem")
            try privateKey.write(to: URL(fileURLWithPath: inkeyPath), atomically: true, encoding: .utf8)
            
            let inPath = try temporaryPath(for: "cert.pem")
            try certificate.write(to: URL(fileURLWithPath: inPath), atomically: true, encoding: .utf8)
            
            let outPath = try temporaryPath(for: "out.p12")
            
            process.arguments = ["pkcs12", "-export", "-out", outPath.spacesEscaped, "-inkey", inkeyPath.spacesEscaped, "-in", inPath.spacesEscaped, "-passout", "pass:\(passphrase)", "-name", friendlyName.spacesEscaped]
            
            process.terminationHandler = { _ in
                do {
                    let outData = try Data(contentsOf: URL(fileURLWithPath: outPath))
                    handler(.success(outData))
                } catch  {
                    handler(.failure(error))
                }
                
                // Cleanup
                try? FileManager.default.removeItem(atPath: inkeyPath)
                try? FileManager.default.removeItem(atPath: inPath)
                try? FileManager.default.removeItem(atPath: outPath)
            }
            process.launch()
        } catch {
            handler(.failure(error))
        }
    }
    
    /// Path for file in temporary directory
    ///
    /// - Parameter fileName: File name
    /// - Returns: Path
    /// - Throws: Error creating directory
    private func temporaryPath(for fileName: String) throws -> String {
        let tempDir = (NSTemporaryDirectory() as NSString).appendingPathComponent("org.eduvpn.app.temp") // Added .temp because .app lets the Finder show the folder as an app
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true, attributes: nil)
        let fileURL = URL(fileURLWithPath: (tempDir as NSString).appendingPathComponent(fileName))
        return fileURL.path
    }
}

private extension String {
    
    /// Escapes spaces in a path
    var spacesEscaped: String {
        return replacingOccurrences(of: " ", with: "\\ ")
    }
    
    static let keyPairs = "keyPairs"
}
