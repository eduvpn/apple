//
//  ServerModel.swift
//  eduVPN
//

import Foundation

struct ServersModel: Decodable {
    var servers: [ServerModel]
}

extension ServersModel {
    
    enum ServersModelKeys: String, CodingKey {
        case servers = "server_list"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: ServersModelKeys.self)
        let servers = try container.decode([ServerModel].self, forKey: .servers)

        self.init(servers: servers)
    }
}

struct ServerModel: Decodable {
    
    let providerType: ProviderType = .organization
    var baseUri: URL
    var groupUri: URL?
    
    var displayNames: [String: String]?
    var displayName: String?
      
    var logoUrls: [String: URL]?
    var logoUrl: URL?

}

extension ServerModel {
    
    enum ServerModelKeys: String, CodingKey {
        case baseUri = "base_url"
        case groupUri = "server_group_url"
        case displayName = "display_name"
        case logoUrl = "logo_uri"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: ServerModelKeys.self)
        
        let baseUri = try container.decode(URL.self, forKey: .baseUri)
        let groupUri = try? container.decode(URL.self, forKey: .groupUri)
        
        var displayName: String?
        let displayNames = try? container.decode(Dictionary<String, String>.self, forKey: .displayName)
        
        if let displayNames = displayNames {
            let preferedLocalization = Bundle.preferredLocalizations(from: Array(displayNames.keys))
            for localeIdentifier in preferedLocalization {
                if let displayNameCandidate = displayNames[localeIdentifier] {
                    displayName = displayNameCandidate
                    break
                }
            }
        } else {
            displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        }
        
        var logoUrl: URL?
        let logoUrls: [String: URL]? = try? container.decode([String: URL].self, forKey: .logoUrl)
        
        if let logoUrls = logoUrls {
            let preferedLocalization = Bundle.preferredLocalizations(from: Array(logoUrls.keys))
            for localeIdentifier in preferedLocalization {
                if let logoUrlCandidate = logoUrls[localeIdentifier] {
                    logoUrl = logoUrlCandidate
                    break
                }
            }
        } else {
            logoUrl = try container.decodeIfPresent(URL.self, forKey: .logoUrl)
        }

        self.init(baseUri: baseUri,
                  groupUri: groupUri,
                  displayNames: displayNames,
                  displayName: displayName,
                  logoUrls: logoUrls,
                  logoUrl: logoUrl)
    }
}
