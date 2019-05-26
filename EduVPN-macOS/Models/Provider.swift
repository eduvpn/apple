//
//  Provider.swift
//  eduVPN
//
//  Created by Johan Kool on 28/06/2017.
//  Copyright © 2017-2019 Commons Conservancy.
//

import Foundation

enum ConnectionType: String, Codable {
    case secureInternet
    case instituteAccess
    case custom
    case localConfig
    
    var localizedDescription: String {
        switch self {
        case .secureInternet:
            return NSLocalizedString("Secure Internet", comment: "")
        case .instituteAccess:
            return NSLocalizedString("Institute Access", comment: "")
        case .custom:
            return NSLocalizedString("Custom", comment: "")
        case .localConfig:
            return NSLocalizedString("Local", comment: "")
        }
    }
}

struct Provider: Codable {
    
    let displayName: String
    let baseURL: URL
    let logoURL: URL?
    
    /// The public key of the API, or for connection type `.localConfig`: the common name of the associated certificate
    var publicKey: String?
    
    /// The user name for connection type `.localConfig`, not used for other providers
    var username: String?
    
    let connectionType: ConnectionType
    let authorizationType: AuthorizationType
    
    let authorizationEndpoint: URL?
    var tokenEndpoint: URL?
    
    var id: String {
        return connectionType.rawValue + ":" + baseURL.absoluteString
    }
}

struct ProviderInfo: Codable {
    
    let apiBaseURL: URL
    let authorizationURL: URL
    let tokenURL: URL
    let provider: Provider
}

struct Profile_Mac: Codable {
    
    let profileId: String
    let displayName: String
    let twoFactor: Bool
    let info: ProviderInfo
}
