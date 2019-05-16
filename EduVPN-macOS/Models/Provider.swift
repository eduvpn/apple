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

enum AuthorizationType: Codable {
    
    enum Error: Swift.Error, LocalizedError {
        case decodingError
        
        var errorDescription: String? {
            switch self {
            case .decodingError:
                return NSLocalizedString("Decoding failed", comment: "")
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .decodingError:
                return NSLocalizedString("Try reinstalling eduVPN.", comment: "")
            }
        }
    }
    
    case local
    case distributed
    case federated(authorizationURL: URL, tokenURL: URL)
    
    enum CodingKeys: String, CodingKey {
        case `self`, kind, authorizationURL, tokenURL
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .local:
            try container.encode("local", forKey: .kind)
        case .distributed:
            try container.encode("distributed", forKey: .kind)
        case .federated(let authorizationURL, let tokenURL):
            try container.encode("federated", forKey: .kind)
            try container.encode(authorizationURL, forKey: .authorizationURL)
            try container.encode(tokenURL, forKey: .tokenURL)
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(String.self, forKey: .kind) {
        case "local":
            self = .local
        case "distributed":
            self = .distributed
        case "federated":
            let authorizationURL = try container.decode(URL.self, forKey: .authorizationURL)
            let tokenURL = try container.decode(URL.self, forKey: .tokenURL)
            self = .federated(authorizationURL: authorizationURL, tokenURL: tokenURL)
        default:
            throw Error.decodingError
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

struct Profile: Codable {
    let profileId: String
    let displayName: String
    let twoFactor: Bool
    let info: ProviderInfo
}

enum TwoFactor {
    case totp(String)
    case yubico(String)
    
    var twoFactorType: TwoFactorType {
        switch self {
        case .totp:
            return .totp
        case .yubico:
            return .yubico
        }
    }
}

