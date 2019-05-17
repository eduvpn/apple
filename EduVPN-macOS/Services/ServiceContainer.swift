//
//  ServiceContainer.swift
//  eduVPN
//
//  Created by Johan Kool on 30/06/2017.
//  Copyright © 2017-2019 Commons Conservancy.
//

import Foundation

/// Entrypoint to services
struct ServiceContainer {
    
    /// URL session to perform network requests
    static let urlSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        let urlSession =  URLSession(configuration: configuration)
        return urlSession
    }()
    
    /// Defines configuration values
    static let appConfig: AppConfigType = AppConfig()
    
    /// Installs and connects helper
    static let helperService = HelperService()
    
    /// Discovers providers
    static let providerService = ProviderService(urlSession: urlSession, authenticationService: authenticationService, preferencesService: preferencesService, keychainService: keychainService, configurationService: configurationService, appConfig: appConfig)
    
    /// Registers 2FA
    static let twoFactorService = TwoFactorService(urlSession: urlSession, authenticationService: authenticationService)
    
    /// Authenticates user with provider
    static let authenticationService = AuthenticationService(appConfig: appConfig)
   
    /// Fetches configuration
    static let configurationService = ConfigurationService(urlSession: urlSession, authenticationService: authenticationService, keychainService: keychainService)
    
    /// Connects to VPN
    static let connectionService = ConnectionService(providerService: providerService, configurationService: configurationService, helperService: helperService, keychainService: keychainService, preferencesService: preferencesService)
    
    /// Handles preferences
    static let preferencesService = PreferencesService()
    
    /// Imports, retrieves certificates, signs data
    static let keychainService = KeychainService()
}
