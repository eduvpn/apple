//
//  Config.swift
//  eduVPN
//

import Foundation

// swiftlint:disable identifier_name
struct Config: Decodable {
    
    static var shared: Config = {
        guard let url = Bundle.main.url(forResource: "config", withExtension: "json") else {
            fatalError("This is very much hard coded. If this ever fails. It SHOULD crash.")
        }
        do {
            return try JSONDecoder().decode(Config.self, from: Data(contentsOf: url))
        } catch {
            fatalError("Failed to load config \(url) due to error: \(error)")
        }
    }()

    enum ConfigKeys: String, CodingKey {
        case client_id
        case redirect_url
        case predefined_provider
        case discovery
        case appName
        case apiDiscoveryEnabled
        case supportURL
        case uninstallURL
    }
    
    var clientId: String
    var redirectUrl: URL
    
    var predefinedProvider: URL?
    var discovery: DiscoveryConfig?
    
    var appName: String
    var apiDiscoveryEnabled: Bool?
    var supportURL: URL?
    var uninstallURL: URL?
}

struct DiscoveryConfig: Decodable {
    
    enum DiscoveryConfigKeys: String, CodingKey {
        case server
        case path_institute_access
        case path_institute_access_signature
        case path_secure_internet
        case path_secure_internet_signature
        case signature_public_key
    }
    
    var server: URL
    
    var pathInstituteAccess: String
    var pathInstituteAccessSignature: String
    var pathSecureInternet: String
    var pathSecureInternetSignature: String
    
    var signaturePublicKey: Data?
}

extension Config {
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: ConfigKeys.self)
        
        clientId = try container.decode(String.self, forKey: .client_id)
        redirectUrl = try container.decode(URL.self, forKey: .redirect_url)
        
        predefinedProvider = try container.decodeIfPresent(URL.self, forKey: .predefined_provider)
        discovery = try container.decodeIfPresent(DiscoveryConfig.self, forKey: .discovery)
        
        appName = try container.decode(String.self, forKey: .appName)
        apiDiscoveryEnabled = try? container.decodeIfPresent(Bool.self, forKey: .apiDiscoveryEnabled) ?? false
        supportURL = try? container.decodeIfPresent(URL.self, forKey: .supportURL)
        uninstallURL = try? container.decodeIfPresent(URL.self, forKey: .uninstallURL)
    }
}

extension DiscoveryConfig {
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DiscoveryConfigKeys.self)
        
        server = try container.decode(URL.self, forKey: .server)
        
        pathInstituteAccess = try container.decode(String.self, forKey: .path_institute_access)
        pathInstituteAccessSignature = try container.decode(String.self, forKey: .path_institute_access_signature)
        pathSecureInternet = try container.decode(String.self, forKey: .path_secure_internet)
        pathSecureInternetSignature = try container.decode(String.self, forKey: .path_secure_internet_signature)
        
        let signaturePublicKeyString = try container.decode(String.self, forKey: .signature_public_key)
        signaturePublicKey = Data(base64Encoded: signaturePublicKeyString)
    }
    
    public func path(forServiceType type: StaticService.StaticServiceType) -> String? {
        switch type {
            
        case .instituteAccess:
            return pathInstituteAccess
            
        case .instituteAccessSignature:
            return pathInstituteAccessSignature
            
        case .secureInternet:
            return pathSecureInternet
            
        case .secureInternetSignature:
            return pathSecureInternetSignature
            
        }
    }
}
