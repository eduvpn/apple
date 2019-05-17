//
//  ProviderService.swift
//  eduVPN
//
//  Created by Johan Kool on 06/07/2017.
//  Copyright © 2017-2019 Commons Conservancy.
//

import Foundation
import AppAuth
import Sodium
import os

/// Discovers providers
class ProviderService {
    
    enum Error: Swift.Error, LocalizedError {
        case unknown
        case invalidProvider
        case invalidProviderURL
        case noProviders
        case invalidProviders
        case invalidProviderInfo
        case providerVerificationFailed
        case noProfiles
        case invalidProfiles
        case invalidUserInfo
        case userIsDisabled
        case invalidMessages
        case missingToken
        case invalidConfigFile(displayName: String, containsCert: Bool, containsKey: Bool)
        
        var errorDescription: String? {
            switch self {
            case .unknown:
                return NSLocalizedString("An unknown error occurred", comment: "")
            case .invalidProvider:
                return NSLocalizedString("Invalid provider", comment: "")
            case .invalidProviderURL:
                return NSLocalizedString("Invalid provider URL", comment: "")
            case .noProviders:
                return NSLocalizedString("No providers were discovered", comment: "")
            case .invalidProviders:
                return NSLocalizedString("No valid providers were discovered", comment: "")
            case .invalidProviderInfo:
                return NSLocalizedString("Invalid provider info", comment: "")
            case .providerVerificationFailed:
                return NSLocalizedString("Could not verify providers", comment: "")
            case .noProfiles:
                return NSLocalizedString("No profiles were found for this provider", comment: "")
            case .invalidProfiles:
                return NSLocalizedString("Invalid profiles were found for this provider", comment: "")
            case .invalidUserInfo:
                return NSLocalizedString("Invalid user info was found for this provider", comment: "")
            case .userIsDisabled:
                return NSLocalizedString("User account is disabled", comment: "")
            case .invalidMessages:
                return NSLocalizedString("Invalid messages were received from this provider", comment: "")
            case .missingToken:
                return NSLocalizedString("Profiles could not be retrieved because no valid token was available", comment: "")
            case .invalidConfigFile(let displayName, let containsCert, let containsKey):
                switch (containsCert, containsKey) {
                case (true, true):
                    return NSLocalizedString("The file “\(displayName)” needs to be adjusted because it contains a certificate and a private key", comment: "")
                case (true, false):
                    return NSLocalizedString("The file “\(displayName)” needs to be adjusted because it contains a certificate", comment: "")
                case (false, true):
                    return NSLocalizedString("The file “\(displayName)” needs to be adjusted because it contains a private key", comment: "")
                case (false, false):
                    return NSLocalizedString("The file “\(displayName)” couldn’t be imported", comment: "")
                }
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .invalidProviderURL:
                return NSLocalizedString("Verify URL.", comment: "")
            case .userIsDisabled:
                return NSLocalizedString("Contact your administrator for further details", comment: "")
            case .invalidConfigFile(_, let containsCert, let containsKey):
                switch (containsCert, containsKey) {
                case (true, true):
                    return NSLocalizedString("Do you want to import the certificate and private key into your keychain and remove them from the imported OpenVPN configuration file?", comment: "")
                case (true, false):
                    return NSLocalizedString("Do you want to remove the certificate from the imported OpenVPN configuration file?\n\nYou may be prompted to select a certificate from your keychain when connecting. If you have a certificate and private key you need to import them into your keychain first.", comment: "")
                case (false, true):
                    return NSLocalizedString("Do you want to remove the private key from the imported OpenVPN configuration file?\n\nYou may be prompted to select a certificate from your keychain when connecting. If you have a certificate and private key you need to import them into your keychain first.", comment: "")
                case (false, false):
                    return NSLocalizedString("It is malformed.", comment: "")
                }
            default:
                return NSLocalizedString("Try again later.", comment: "")
            }
        }
        
        var recoveryOptions: [String] {
            switch self {
            case .invalidConfigFile(_, let containsCert, let containsKey):
                switch (containsCert, containsKey) {
                case (true, true):
                    return [NSLocalizedString("Import into Keychain", comment: ""), NSLocalizedString("Cancel", comment: "")]
                case (true, false):
                    return [NSLocalizedString("Remove Certificate", comment: ""), NSLocalizedString("Cancel", comment: "")]
                case (false, true):
                    return [NSLocalizedString("Remove Private Key", comment: ""), NSLocalizedString("Cancel", comment: "")]
                case (false, false):
                    return []
                }
            default:
                return []
            }
        }
    }
    
    private let urlSession: URLSession
    private let authenticationService: AuthenticationService
    private let preferencesService: PreferencesService
    private let keychainService: KeychainService
    private let configurationService: ConfigurationService
    private let appConfig: AppConfigType
    private let log: OSLog
    
    init(urlSession: URLSession, authenticationService: AuthenticationService, preferencesService: PreferencesService, keychainService: KeychainService, configurationService: ConfigurationService, appConfig: AppConfigType) {
        self.urlSession = urlSession
        self.authenticationService = authenticationService
        self.preferencesService = preferencesService
        self.keychainService = keychainService
        self.configurationService = configurationService
        self.appConfig = appConfig
        
        if ProcessInfo.processInfo.environment.keys.contains("SIGNPOSTS") {
            log = OSLog(subsystem: "org.eduvpn.app.home", category: "ProviderService")
        } else {
            log = .disabled
        }
        
        readFromDisk()
    }
    
    /// Discovers all providers that the user can access with the stored providers
    ///
    /// - Parameter handler: List of providers or error
    func discoverAccessibleProviders(handler: @escaping (Result<[ConnectionType: [Provider]]>) -> ()) {
        let discoverID: Any?
        if #available(OSX 10.14, *) {
            discoverID = OSSignpostID(log: log)
            os_signpost(.begin, log: log, name: "Discover Accessible Providers", signpostID: discoverID as! OSSignpostID)
        } else {
            discoverID = nil
        }
        
        if !appConfig.apiDiscoveryEnabled {
            var accessibleProviders: [ConnectionType: [Provider]] = [:]
            
            func hasStoredDistributedProvider(type: ConnectionType) -> Bool {
                guard let providers = self.storedProviders[type] else {
                    return false
                }
                return providers.contains { (provider) -> Bool in
                    switch provider.authorizationType {
                    case .local:
                        return false
                    case .distributed, .federated:
                        return true
                    }
                }
            }
            
            func addProviders(type: ConnectionType) {
                if hasStoredDistributedProvider(type: type) {
                    // Add all providers
                    if let providers = self.availableProviders[type] {
                        accessibleProviders[type] = providers
                    }
                } else {
                    // Add stored providers
                    if let providers = self.storedProviders[type] {
                        accessibleProviders[type] = providers
                    }
                }
            }
            
            addProviders(type: .custom)
            addProviders(type: .localConfig)
            
            handler(.success(accessibleProviders))
            
            if #available(OSX 10.14, *) {
                os_signpost(.end, log: log, name: "Discover Accessible Providers", signpostID: discoverID as! OSSignpostID, "API Discovery Disabled")
            }
        } else {
            
            let group = DispatchGroup()
            var error: Error? = nil
            
            func discoverAvailableProviders(type: ConnectionType) {
                group.enter()
                discoverProviders(connectionType: type) { (result) in
                    switch result {
                    case .success(let providers):
                        self.availableProviders[type] = providers
                    case .failure(let discoverError):
                        error = discoverError as? Error
                    }
                    group.leave()
                }
            }
            
            discoverAvailableProviders(type: .secureInternet)
            discoverAvailableProviders(type: .instituteAccess)
            
            group.notify(queue: .main) {
                if let error = error {
                    handler(.failure(error))
                    if #available(OSX 10.14, *) {
                        os_signpost(.end, log: self.log, name: "Discover Accessible Providers", signpostID: discoverID as! OSSignpostID, "Error")
                    }
                    return
                }
                
                var accessibleProviders: [ConnectionType: [Provider]] = [:]
                
                func hasStoredDistributedProvider(type: ConnectionType) -> Bool {
                    guard let providers = self.storedProviders[type] else {
                        return false
                    }
                    return providers.contains { (provider) -> Bool in
                        switch provider.authorizationType {
                        case .local:
                            return false
                        case .distributed, .federated:
                            return true
                        }
                    }
                }
                
                func addProviders(type: ConnectionType) {
                    if hasStoredDistributedProvider(type: type) {
                        // Add all providers
                        if let providers = self.availableProviders[type] {
                            accessibleProviders[type] = providers
                        }
                    } else {
                        // Add stored providers
                        if let providers = self.storedProviders[type] {
                            accessibleProviders[type] = providers
                        }
                    }
                }
                
                addProviders(type: .secureInternet)
                addProviders(type: .instituteAccess)
                addProviders(type: .custom)
                addProviders(type: .localConfig)
                
                handler(.success(accessibleProviders))
                if #available(OSX 10.14, *) {
                    os_signpost(.end, log: self.log, name: "Discover Accessible Providers", signpostID: discoverID as! OSSignpostID, "Success")
                }
            }
        }
    }
    
    /// Indicates wether at least one provider is setup
    var hasAtLeastOneStoredProvider: Bool {
        return !storedProviders.flatMap({ $0.value }).isEmpty
    }
    
    /// All providers
    private var availableProviders: [ConnectionType: [Provider]] = [:]
    
    /// Providers with which the user has authenticated
    private(set) var storedProviders: [ConnectionType: [Provider]] = [:]
    
    /// Stores provider and saves it to disk
    ///
    /// - Parameter provider: provider
    func storeProvider(provider: Provider) {
        guard provider.connectionType != .localConfig else {
            return
        }
        let connectionType = provider.connectionType
        var providers = storedProviders[connectionType] ?? []
        let index = providers.index(where: { $0.id == provider.id })
        if let index = index {
            providers.remove(at: index)
            providers.insert(provider, at: index)
        } else {
            providers.append(provider)
        }
        storedProviders[connectionType] = providers
        saveToDisk()
    }
    
    /// Removes provider and saves to disk
    ///
    /// - Parameter provider: provider
    func deleteProvider(provider: Provider) {
        let connectionType = provider.connectionType
        
        switch connectionType {
        case .localConfig:
            // For local config: delete config
            try? FileManager.default.removeItem(at: provider.baseURL)
            // Do NOT delete selected certificate/identity
        case .instituteAccess, .secureInternet, .custom:
            // Remove identity
            configurationService.removeIdentity(for: provider)
        }
        
        // Remove tokens
        authenticationService.deauthenticate(for: provider)
        
        var providers = storedProviders[connectionType] ?? []
        let index = providers.index(where: { (otherProvider) -> Bool in
            return otherProvider.id == provider.id
        })
        
        if let index = index {
            providers.remove(at: index)
            storedProviders[connectionType] = providers
            saveToDisk()
        }
    }
    
    /// URL for Application Support folder
    ///
    /// - Returns: URL
    /// - Throws: Error finding or creating directory
    private func applicationSupportDirectoryURL() throws -> URL  {
        var applicationSupportDirectory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        applicationSupportDirectory.appendPathComponent(appConfig.appName)
        try FileManager.default.createDirectory(at: applicationSupportDirectory, withIntermediateDirectories: true, attributes: nil)
        return applicationSupportDirectory
    }
    
    /// URL for saving providers to disk
    ///
    /// - Returns: URL
    /// - Throws: Error finding or creating directory
    private func storedProvidersFileURL() throws -> URL  {
        var storedProvidersFileURL = try applicationSupportDirectoryURL()
        storedProvidersFileURL.appendPathComponent("Providers.plist")
        return storedProvidersFileURL
    }
    
    /// URL for saving local configs
    ///
    /// - Returns: URL
    /// - Throws: Error finding or creating directory
    private func localConfigsDirectoryURL() throws -> URL  {
        var localConfigsDirectoryURL = try applicationSupportDirectoryURL()
        localConfigsDirectoryURL.appendPathComponent("Local")
        try FileManager.default.createDirectory(at: localConfigsDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        return localConfigsDirectoryURL
    }
    
    /// Reads providers from disk
    private func readFromDisk() {
        let decoder = PropertyListDecoder()
        do {
            let url = try storedProvidersFileURL()
            let data = try Data(contentsOf: url)
            let restoredProviders = try decoder.decode([ConnectionType: [Provider]].self, from: data)
            storedProviders = restoredProviders
        } catch (let error) {
            NSLog("Failed to read stored providers from disk at \(url): \(error)")
        }
    }
    
    /// Saves providers to disk
    private func saveToDisk() {
        let encoder = PropertyListEncoder()
        do {
            let data = try encoder.encode(storedProviders)
            let url = try storedProvidersFileURL()
            try data.write(to: url, options: .atomic)
        } catch (let error) {
            NSLog("Failed to write stored providers to disk at \(url): \(error)")
        }
    }
    
    /// Returns discovery URL
    ///
    /// - Parameter connectionType: Connection type
    /// - Returns: URL
    private func url(for connectionType: ConnectionType) -> URL {
        let developerMode = preferencesService.developerMode
        let path: String
        switch (connectionType, developerMode) {
        case (.secureInternet, false):
            path = "secure_internet"
        case (.secureInternet, true):
            path = "secure_internet_dev"
        case (.instituteAccess, false):
            path = "institute_access"
        case (.instituteAccess, true):
            path = "institute_access_dev"
        case (.custom, _), (.localConfig, _):
            fatalError("Can't discover custom providers")
        }
        return URL(string: path + ".json", relativeTo: URL(string: "https://static.eduvpn.nl/disco/")!)!
    }
    
    /// Returns discovery signature URL
    ///
    /// - Parameter connectionType: Connection type
    /// - Returns: URL
    private func signatureUrl(for connectionType: ConnectionType) -> URL {
        let developerMode = preferencesService.developerMode
        let path: String
        switch (connectionType, developerMode) {
        case (.secureInternet, false):
            path = "secure_internet"
        case (.secureInternet, true):
            path = "secure_internet_dev"
        case (.instituteAccess, false):
            path = "institute_access"
        case (.instituteAccess, true):
            path = "institute_access_dev"
        case (.custom, _), (.localConfig, _):
            fatalError("Can't discover custom provider signatures")
        }
        return URL(string: path + ".json.sig", relativeTo: URL(string: "https://static.eduvpn.nl/disco/")!)!
    }
    
    /// Discovers providers for a connection type
    ///
    /// - Parameters:
    ///   - connectionType: Connection type
    ///   - handler: List of providers or error
    func discoverProviders(connectionType: ConnectionType, handler: @escaping (Result<[Provider]>) -> ()) {
        let request = URLRequest(url: signatureUrl(for: connectionType))
        let task = urlSession.dataTask(with: request) { (data, response, error) in
            guard let signature = data, let response = response as? HTTPURLResponse, 200..<300 ~= response.statusCode else {
                handler(.failure(error ?? Error.unknown))
                return
            }
            discoverProviders(signature: signature)
        }
        task.resume()
        
        func discoverProviders(signature: Data) {
            let request = URLRequest(url: url(for: connectionType))
            let task = urlSession.dataTask(with: request) { (data, response, error) in
                guard let data = data, let response = response as? HTTPURLResponse, 200..<300 ~= response.statusCode else {
                    handler(.failure(error ?? Error.unknown))
                    return
                }
                do {
                    let sodium = Sodium()
                    
                    guard let signatureBin = NSData(base64Encoded: signature, options: []) as Data? else {
                        handler(.failure(Error.providerVerificationFailed))
                        return
                    }
                    
                    let developerMode = self.preferencesService.developerMode
                    let publicKeyString = developerMode ? "zzls4TZTXHEyV3yxaxag1DZw3tSpIdBoaaOjUGH/Rwg=" : "E5On0JTtyUVZmcWd+I/FXRm32nSq8R2ioyW7dcu/U88="
                    guard let publicKey = NSData(base64Encoded: publicKeyString, options: []) as Data? else {
                        handler(.failure(Error.providerVerificationFailed))
                        return
                    }
                    
                    guard sodium.sign.verify(message: Array(data), publicKey: Array(publicKey), signature: Array(signatureBin)) else {
                        handler(.failure(Error.invalidProviders))
                        return
                    }
                    
                    guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? NSDictionary else {
                        handler(.failure(Error.invalidProviders))
                        return
                    }
                    
                    let authorizationType: AuthorizationType
                    switch json["authorization_type"] as? String ?? "" {
                    case "local":
                        authorizationType = .local
                    case "distributed":
                        authorizationType = .distributed
                    case "federated":
                        guard let authorizationURL = (json["authorization_endpoint"] as? String)?.asURL(),
                            let tokenURL = (json["token_endpoint"] as? String)?.asURL() else {
                            handler(.failure(Error.invalidProviders))
                            return
                        }
                        authorizationType = .federated(authorizationURL: authorizationURL, tokenURL: tokenURL)
                    default:
                        handler(.failure(Error.invalidProviders))
                        return
                    }
                    
                    guard let instances = json.value(forKeyPath: "instances") as? [[String: AnyObject]] else {
                        handler(.failure(Error.invalidProviders))
                        return
                    }
                    
                    func displayName(for instance: [String: AnyObject]) -> String? {
                        if let displayName = instance["display_name"] as? String {
                            return displayName
                        } else if let localizedDisplayNames = instance["display_name"] as? [String: String] {
                            for (_, locale) in Locale.preferredLanguages.enumerated() {
                                if let displayName = localizedDisplayNames[locale] {
                                    return displayName
                                }
                            }
                            
                            // Language region combo, e.g. en-NL is not available, try to match on language only
                            for (_, locale) in Locale.preferredLanguages.enumerated() {
                                guard let languageSubstring = locale.split(separator: "-").first else {
                                    continue
                                }
                                let language = String(languageSubstring) 
                                for (key, displayName) in localizedDisplayNames {
                                    if key.hasPrefix(language) {
                                        return displayName
                                    }
                                }
                            }
                            
                            // Fallback
                            return localizedDisplayNames.values.first
                        }
                        
                        return nil
                    }
                    
                    let providers: [Provider] = instances.compactMap { (instance) -> Provider? in                        
                        guard let displayName = displayName(for: instance),
                            let baseURL = (instance["base_uri"] as? String)?.asURL(appendSlash: true),
                            let logoURL = (instance["logo"] as? String)?.asURL() else {
                                return nil
                        }
                        
                        let publicKey = instance["public_key"] as? String
                        
                        return Provider(displayName: displayName, baseURL: baseURL, logoURL: logoURL, publicKey: publicKey, username: nil, connectionType: connectionType, authorizationType: authorizationType)
                    }
                    
                    guard !providers.isEmpty else {
                        handler(.failure(Error.noProviders))
                        return
                    }
                    
                    handler(.success(providers))
                } catch(let error) {
                    handler(.failure(error))
                    return
                }
            }
            task.resume()
        }
    }
    
    /// Fetches info about provider
    ///
    /// - Parameters:
    ///   - provider: Provider
    ///   - handler: Info about provider or error
    func fetchInfo(for provider: Provider, handler: @escaping (Result<ProviderInfo>) -> ()) {
        guard provider.connectionType != .localConfig else {
            let providerInfo = ProviderInfo(apiBaseURL: URL(fileURLWithPath: "/dev/null"), authorizationURL: URL(fileURLWithPath: "/dev/null"), tokenURL: URL(fileURLWithPath: "/dev/null"), provider: provider)
            handler(.success(providerInfo))
            return
        }
        
        guard let url = URL(string: "info.json", relativeTo: provider.baseURL) else {
            handler(.failure(Error.invalidProvider))
            return
        }
        
        let fetchInfoID: Any?
        if #available(OSX 10.14, *) {
            fetchInfoID = OSSignpostID(log: log)
            os_signpost(.begin, log: log, name: "Fetch Provider Info", signpostID: fetchInfoID as! OSSignpostID, "%{public}s", provider.displayName)
        } else {
            fetchInfoID = nil
        }
        
        let request = URLRequest(url:url)
        let task = urlSession.dataTask(with: request) { (data, response, error) in
            defer {
                if #available(OSX 10.14, *) {
                    os_signpost(.end, log: self.log, name: "Fetch Provider Info", signpostID: fetchInfoID as! OSSignpostID)
                }
            }
            guard let data = data, let response = response as? HTTPURLResponse, 200..<300 ~= response.statusCode else {
                switch provider.connectionType {
                case .secureInternet, .instituteAccess:
                    handler(.failure(error ?? Error.unknown))
                case .custom:
                    handler(.failure(error ?? Error.invalidProviderURL))
                case .localConfig:
                    fatalError("Can't fetch provider info for local config")
                }
                return
            }
            do {
                guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? NSDictionary else {
                    handler(.failure(Error.invalidProviders))
                    return
                }
                
                guard let api = json.value(forKeyPath: "api.http://eduvpn.org/api#2") as? [String: AnyObject] else {
                    handler(.failure(Error.invalidProviderInfo))
                    return
                }
                
                guard let apiBaseURL = (api["api_base_uri"] as? String)?.asURL(appendSlash: true),
                    let authorizationURL = (api["authorization_endpoint"] as? String)?.asURL(),
                    let tokenURL = (api["token_endpoint"] as? String)?.asURL() else {
                        handler(.failure(Error.invalidProviderInfo))
                        return
                }
                
                let providerInfo = ProviderInfo(apiBaseURL: apiBaseURL, authorizationURL: authorizationURL, tokenURL: tokenURL, provider: provider)
                handler(.success(providerInfo))
            } catch(let error) {
                handler(.failure(error))
                return
            }
        }
        task.resume()
    }

    /// Fetches both user info and profiles available for provider
    ///
    /// - Parameters:
    ///   - info: Provider info
    ///   - handler: User info and profiles or error
    func fetchUserInfoAndProfiles(for info: ProviderInfo, handler: @escaping (Result<(UserInfo, [Profile])>) -> ()) {
        guard info.provider.connectionType != .localConfig else {
            let userInfo = UserInfo(twoFactorEnrolled: false, twoFactorEnrolledWith: [], isDisabled: false)
            let profile = Profile(profileId: info.provider.displayName, displayName: info.provider.displayName, twoFactor: false, info: info)
            handler(.success((userInfo, [profile])))
            return
        }

        let fetchInfoID: Any?
        if #available(OSX 10.14, *) {
            fetchInfoID = OSSignpostID(log: log)
            os_signpost(.begin, log: log, name: "Fetch User Info and Profiles", signpostID: fetchInfoID as! OSSignpostID, "%{public}s", info.provider.displayName)
        } else {
            fetchInfoID = nil
        }
        
        let group = DispatchGroup()
        var userInfo: UserInfo? = nil
        var profiles: [Profile]? = nil
        var error: Swift.Error? = nil
        
        group.enter()
        fetchUserInfo(for: info) { (result) in
            switch result {
            case .success(let fetchedUserInfo):
                userInfo = fetchedUserInfo
            case .failure(let fetchedError):
                error = fetchedError
            }
            group.leave()
        }
        
        group.enter()
        fetchProfiles(for: info) { (result) in
            switch result {
            case .success(let fetchedProfiles):
                profiles = fetchedProfiles
            case .failure(let fetchedError):
                error = fetchedError
            }
            group.leave()
        }
        
        group.notify(queue: .main) {
            defer {
                if #available(OSX 10.14, *) {
                    os_signpost(.end, log: self.log, name: "Fetch User Info and Profiles", signpostID: fetchInfoID as! OSSignpostID)
                }
            }
            if let error = error {
                handler(.failure(error))
                return
            }
            handler(.success((userInfo!, profiles!)))
        }
    }
    
    /// Fetch user info
    ///
    /// - Parameters:
    ///   - info: Provider info
    ///   - authenticationBehavior: Whether authentication should be retried when token is revoked or expired
    ///   - handler: User info or error
    func fetchUserInfo(for info: ProviderInfo, authenticationBehavior: AuthenticationService.Behavior = .ifNeeded, handler: @escaping (Result<UserInfo>) -> ()) {
        let path: String = "user_info"
        
        guard let url = URL(string: path, relativeTo: info.apiBaseURL) else {
            handler(.failure(Error.invalidProviderInfo))
            return
        }
        
        let fetchInfoID: Any?
        if #available(OSX 10.14, *) {
            fetchInfoID = OSSignpostID(log: log)
            os_signpost(.begin, log: log, name: "Fetch User Info", signpostID: fetchInfoID as! OSSignpostID, "%{public}s", info.provider.displayName)
        } else {
            fetchInfoID = nil
        }
        
        authenticationService.performAction(for: info, authenticationBehavior: authenticationBehavior) { (accessToken, idToken, error) in
            guard let accessToken = accessToken else {
                handler(.failure(error ?? Error.missingToken))
                if #available(OSX 10.14, *) {
                    os_signpost(.end, log: self.log, name: "Fetch User Info", signpostID: fetchInfoID as! OSSignpostID, "Failure")
                }
                return
            }
            var request = URLRequest(url: url)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            
            let task = self.urlSession.dataTask(with: request) { (data, response, error) in
                defer {
                    if #available(OSX 10.14, *) {
                        os_signpost(.end, log: self.log, name: "Fetch User Info", signpostID: fetchInfoID as! OSSignpostID)
                    }
                }
                guard let data = data, let response = response as? HTTPURLResponse else {
                    handler(.failure(error ?? Error.unknown))
                    return
                }
                
                guard response.statusCode != 401 else {
                    // Unauthorized! Try to authenticate again
                    self.fetchUserInfo(for: info, authenticationBehavior: .always, handler: handler)
                    return
                }
                
                guard 200..<300 ~= response.statusCode else {
                    handler(.failure(error ?? Error.unknown))
                    return
                }
                
                do {
                    guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? NSDictionary else {
                        handler(.failure(Error.invalidUserInfo))
                        return
                    }
                    
                    guard let instance = json.value(forKeyPath: path + ".data") as? [String: AnyObject] else {
                        handler(.failure(Error.invalidUserInfo))
                        return
                    }
                    
                    guard let twoFactorEnrolled = instance["two_factor_enrolled"] as? Bool else {
                        handler(.failure(Error.invalidUserInfo))
                        return
                    }
                    
                    guard let twoFactorEnrolledWithStrings = instance["two_factor_enrolled_with"] as? [String] else {
                        handler(.failure(Error.invalidUserInfo))
                        return
                    }
                    
                    let twoFactorEnrolledWith = twoFactorEnrolledWithStrings.compactMap({ TwoFactorType(rawValue: $0) })
                    guard let isDisabled = instance["is_disabled"] as? Bool else {
                        handler(.failure(Error.invalidUserInfo))
                        return
                    }
                    
                    let userInfo = UserInfo(twoFactorEnrolled: twoFactorEnrolled, twoFactorEnrolledWith: twoFactorEnrolledWith, isDisabled: isDisabled)
                    
                    if userInfo.isDisabled {
                        handler(.failure(Error.userIsDisabled))
                    } else {
                        handler(.success(userInfo))
                    }
                } catch(let error) {
                    handler(.failure(error))
                    return
                }
            }
            task.resume()
        }
    }
    
    /// Fetches profiles available for provider
    ///
    /// - Parameters:
    ///   - info: Provider info
    ///   - authenticationBehavior: Whether authentication should be retried when token is revoked or expired
    ///   - handler: Profiles or error
    func fetchProfiles(for info: ProviderInfo, authenticationBehavior: AuthenticationService.Behavior = .ifNeeded, handler: @escaping (Result<[Profile]>) -> ()) {
        guard let url = URL(string: "profile_list", relativeTo: info.apiBaseURL) else {
            handler(.failure(Error.invalidProviderInfo))
            return
        }
        
        let fetchInfoID: Any?
        if #available(OSX 10.14, *) {
            fetchInfoID = OSSignpostID(log: log)
            os_signpost(.begin, log: log, name: "Fetch Profiles", signpostID: fetchInfoID as! OSSignpostID, "%{public}s", info.provider.displayName)
        } else {
            fetchInfoID = nil
        }
        
        authenticationService.performAction(for: info, authenticationBehavior: authenticationBehavior) { (accessToken, idToken, error) in
            guard let accessToken = accessToken else {
                handler(.failure(error ?? Error.missingToken))
                if #available(OSX 10.14, *) {
                    os_signpost(.end, log: self.log, name: "Fetch Profiles", signpostID: fetchInfoID as! OSSignpostID, "Failure")
                }
                return
            }
            var request = URLRequest(url: url)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            
            let task = self.urlSession.dataTask(with: request) { (data, response, error) in
                defer {
                    if #available(OSX 10.14, *) {
                        os_signpost(.end, log: self.log, name: "Fetch Profiles", signpostID: fetchInfoID as! OSSignpostID)
                    }
                }
                
                guard let data = data, let response = response as? HTTPURLResponse else {
                    handler(.failure(error ?? Error.unknown))
                    return
                }
                
                guard response.statusCode != 401 else {
                    // Unauthorized! Try to authenticate again
                    self.fetchProfiles(for: info, authenticationBehavior: .always, handler: handler)
                    return
                }
                
                guard 200..<300 ~= response.statusCode else {
                    handler(.failure(error ?? Error.unknown))
                    return
                }
                
                do {
                    guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? NSDictionary else {
                        handler(.failure(Error.invalidProfiles))
                        return
                    }
                    
                    guard let instances = json.value(forKeyPath: "profile_list.data") as? [[String: AnyObject]] else {
                        handler(.failure(Error.invalidProfiles))
                        return
                    }
                    
                    let profiles: [Profile] = instances.compactMap { (instance) -> Profile? in
                        guard let displayName = instance["display_name"] as? String,
                            let profileId = instance["profile_id"] as? String else {
                                return nil
                        }
                        let twoFactor = instance["two_factor"] as? Bool
                        return Profile(profileId: profileId, displayName: displayName, twoFactor: twoFactor ?? false, info: info)
                    }
                    
                    guard !profiles.isEmpty else {
                        handler(.failure(Error.noProfiles))
                        return
                    }
                    
                    handler(.success(profiles))
                } catch(let error) {
                    handler(.failure(error))
                    return
                }
            }
            task.resume()
        }
    }

    private lazy var dateFormatter = ISO8601DateFormatter()
    
    /// Fetch system or user messages
    ///
    /// - Parameters:
    ///   - info: Provider info
    ///   - audience: System or user
    ///   - authenticationBehavior: Whether authentication should be retried when token is revoked or expired
    ///   - handler: Messages or error
    func fetchMessages(for info: ProviderInfo, audience: MessageAudience, authenticationBehavior: AuthenticationService.Behavior = .ifNeeded, handler: @escaping (Result<[Message]>) -> ()) {
        let path: String
        switch audience {
        case .system:
            path = "system_messages"
        case .user:
            path = "user_messages"
        }
        
        guard let url = URL(string: path, relativeTo: info.apiBaseURL) else {
            handler(.failure(Error.invalidProviderInfo))
            return
        }
        
        let fetchInfoID: Any?
        if #available(OSX 10.14, *) {
            fetchInfoID = OSSignpostID(log: log)
            os_signpost(.begin, log: log, name: "Fetch Messages", signpostID: fetchInfoID as! OSSignpostID, "%{public}s %{public}s", info.provider.displayName, path)
        } else {
            fetchInfoID = nil
        }
        
        authenticationService.performAction(for: info, authenticationBehavior: authenticationBehavior) { (accessToken, idToken, error) in
            guard let accessToken = accessToken else {
                handler(.failure(error ?? Error.missingToken))
                defer {
                    if #available(OSX 10.14, *) {
                        os_signpost(.end, log: self.log, name: "Fetch Messages", signpostID: fetchInfoID as! OSSignpostID, "Failure")
                    }
                }
                return
            }
            var request = URLRequest(url: url)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            
            let task = self.urlSession.dataTask(with: request) { (data, response, error) in
                defer {
                    if #available(OSX 10.14, *) {
                        os_signpost(.end, log: self.log, name: "Fetch Messages", signpostID: fetchInfoID as! OSSignpostID)
                    }
                }
                
                guard let data = data, let response = response as? HTTPURLResponse else {
                    handler(.failure(error ?? Error.unknown))
                    return
                }
                
                guard response.statusCode != 401 else {
                    // Unauthorized! Try to authenticate again
                    self.fetchMessages(for: info, audience: audience, authenticationBehavior: .always, handler: handler)
                    return
                }
                
                guard 200..<300 ~= response.statusCode else {
                    handler(.failure(error ?? Error.unknown))
                    return
                }
                
                do {
                    guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? NSDictionary else {
                        handler(.failure(Error.invalidMessages))
                        return
                    }
                    
                    guard let instances = json.value(forKeyPath: path + ".data") as? [[String: AnyObject]] else {
                        handler(.failure(Error.invalidMessages))
                        return
                    }
                    
                    let messages: [Message] = instances.compactMap { (instance) -> Message? in
                        guard let typeString = instance["type"] as? String, let type = MessageType(rawValue: typeString) else {
                            return nil
                        }
                        guard let message = instance["message"] as? String else {
                            return nil
                        }
                        guard let dateString = instance["date_time"] as? String, let date = self.dateFormatter.date(from: dateString) else {
                            return nil
                        }
                        let beginDateString = instance["begin"] as? String
                        let beginDate = self.dateFormatter.date(from: beginDateString ?? "")
                        let endDateString = instance["end"] as? String
                        let endDate = self.dateFormatter.date(from: endDateString ?? "")
                        
                        return Message(type: type, audience: audience, message: message, date: date, beginDate: beginDate, endDate: endDate)
                    }
                    
                    handler(.success(messages))
                } catch(let error) {
                    handler(.failure(error))
                    return
                }
            }
            task.resume()
        }
    }
    
    func addProvider(configFileURL: URL, recover: Bool = false, handler: @escaping ((Result<Provider>) -> Void))  {
        configFileCheck(configFileURL: configFileURL, recover: recover) { result in
            switch result {
            case .success(let config, let commonName):
                do {
                    // Copy to Application Support folder
                    let localConfigsDirectoryURL = try self.localConfigsDirectoryURL()
                    var displayName = configFileURL.lastPathComponent
                    let importedConfigFileURL = try localConfigsDirectoryURL.appendingPathComponent(displayName).nextUnusedFileURL()
                    displayName = importedConfigFileURL.lastPathComponent
                    try config.write(to: importedConfigFileURL, atomically: true, encoding: .utf8)
                    let provider = Provider(displayName: displayName, baseURL: importedConfigFileURL, logoURL: nil, publicKey: commonName, username: nil, connectionType: .localConfig, authorizationType: .local)
                    if self.storedProviders[.localConfig] != nil {
                        self.storedProviders[.localConfig]?.append(provider)
                    } else {
                        self.storedProviders[.localConfig] = [provider]
                    }
                    self.saveToDisk()
                    handler(.success(provider))
                } catch {
                    handler(.failure(error))
                }
            case .failure(let error):
                handler(.failure(error))
            }
        }
    }
    
    private func configFileCheck(configFileURL: URL, recover: Bool, handler: @escaping ((Result<(Config, String?)>) -> Void)) {
        do {
            let config = try String(contentsOf: configFileURL)
            let certStartRange = config.range(of: "<cert>")
            let certEndRange = config.range(of: "</cert>")
            let keyStartRange = config.range(of: "<key>")
            let keyEndRange = config.range(of: "</key>")
            
            func remove(from config: String) -> String {
                var config = config
                
                let certStartRange = config.range(of: "<cert>")
                let certEndRange = config.range(of: "</cert>")
                if let certStartRange = certStartRange, let certEndRange = certEndRange, certStartRange.upperBound < certEndRange.lowerBound {
                    config.removeSubrange(certStartRange.lowerBound...certEndRange.upperBound)
                }
                
                let keyStartRange = config.range(of: "<key>")
                let keyEndRange = config.range(of: "</key>")
                if let keyStartRange = keyStartRange, let keyEndRange = keyEndRange, keyStartRange.upperBound < keyEndRange.lowerBound {
                    config.removeSubrange(keyStartRange.lowerBound...keyEndRange.upperBound)
                }
                return config
            }
            
            if certStartRange == nil, certEndRange == nil, keyStartRange == nil, keyEndRange == nil {
                handler(.success((config, nil)))
            } else {
                let certificate: String?
                if let certStartRange = certStartRange, let certEndRange = certEndRange, certStartRange.upperBound < certEndRange.lowerBound {
                    certificate = String(config[certStartRange.upperBound..<certEndRange.lowerBound])
                } else {
                    certificate = nil
                }
                let privateKey: String?
                if let keyStartRange = keyStartRange, let keyEndRange = keyEndRange, keyStartRange.upperBound < keyEndRange.lowerBound {
                    privateKey = String(config[keyStartRange.upperBound..<keyEndRange.lowerBound])
                } else {
                    privateKey = nil
                }
                
                if recover {
                    if let certificate = certificate, let privateKey = privateKey {
                        // Import into Keychain
                        let passphrase = String.random()
                        let friendlyName = configFileURL.lastPathComponent
                        configurationService.createPKCS12(certificate: certificate, privateKey: privateKey, passphrase: passphrase, friendlyName: friendlyName) { result in
                            switch result {
                            case .success(let data):
                                let commonName = try? self.keychainService.importKeyPair(data: data, passphrase: passphrase)
                                // Remove Certificate and Private Key
                                handler(.success((remove(from: config), commonName)))
                                break
                            case .failure(let error):
                                dump(error)
                                handler(.failure(error))
                                break
                            }
                        }
                        
                        return
                    } else if let _ = certificate {
                        // Remove Certificate
                        handler(.success((remove(from: config), nil)))
                    } else if let _ = privateKey {
                        // Remove Private Key
                        handler(.success((remove(from: config), nil)))
                    } else {
                        let displayName = FileManager.default.displayName(atPath: configFileURL.path)
                        let error = Error.invalidConfigFile(displayName: displayName, containsCert: false, containsKey: false)
                        handler(.failure(error))
                    }
                } else {
                    
                    let displayName = FileManager.default.displayName(atPath: configFileURL.path)
                    let error = Error.invalidConfigFile(displayName: displayName, containsCert: certificate != nil, containsKey: privateKey != nil)
                    handler(.failure(error))
                }
            }
        } catch {
            handler(.failure(error))
        }
    }
    
    func saveCommonCertificate(_ name: String?, username: String?, for provider: Provider) {
        guard provider.connectionType == .localConfig else {
            return
        }
        
        if provider.publicKey == name && provider.username == username {
            return
        }
        
        var providers = storedProviders[.localConfig] ?? []
        let index = providers.index(where: { $0.id == provider.id })
        if let index = index {
            var storedProvider = providers.remove(at: index)
            storedProvider.publicKey = name
            storedProvider.username = username
            providers.insert(storedProvider, at: index)
        } else {
            var newProvider = provider
            newProvider.publicKey = name
            newProvider.username = username
            providers.append(newProvider)
        }

        storedProviders[.localConfig] = providers
        saveToDisk()
    }
    
}
