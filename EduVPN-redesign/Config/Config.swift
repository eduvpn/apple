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
    var discovery: DiscoveryConfig
    
    var appName: String
    var apiDiscoveryEnabled: Bool?
    var supportURL: URL?
    var uninstallURL: URL?
}

struct DiscoveryConfig: Decodable {
    
    enum DiscoveryConfigKeys: String, CodingKey {
        case server_list
        case server_list_signature
        case organization_list
        case organization_list_signature
        case signature_public_keys
    }
    
    var serverList: URL
    var serverListSignature: URL
    
    var organizationList: URL
    var organizationListSignature: URL
    
    var signaturePublicKeys: [Data]
}

extension Config {
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: ConfigKeys.self)
        
        clientId = try container.decode(String.self, forKey: .client_id)
        redirectUrl = try container.decode(URL.self, forKey: .redirect_url)
        
        predefinedProvider = try container.decodeIfPresent(URL.self, forKey: .predefined_provider)
        discovery = try container.decode(DiscoveryConfig.self, forKey: .discovery)
        
        appName = try container.decode(String.self, forKey: .appName)
        apiDiscoveryEnabled = try? container.decodeIfPresent(Bool.self, forKey: .apiDiscoveryEnabled) ?? false
        supportURL = try? container.decodeIfPresent(URL.self, forKey: .supportURL)
        uninstallURL = try? container.decodeIfPresent(URL.self, forKey: .uninstallURL)
    }
}

extension DiscoveryConfig {
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DiscoveryConfigKeys.self)
        
        serverList = try container.decode(URL.self, forKey: .server_list)
        serverListSignature = try container.decode(URL.self, forKey: .server_list_signature)
        organizationList = try container.decode(URL.self, forKey: .organization_list)
        organizationListSignature = try container.decode(URL.self, forKey: .organization_list_signature)
        
        let signaturePublicKeyStrings = try container.decode([String].self, forKey: .signature_public_keys)
        signaturePublicKeys = signaturePublicKeyStrings.compactMap { Data(base64Encoded: $0) }
    }
}
