//
//  ServerModel.swift
//  eduVPN
//

import Foundation

struct ServersModel: Decodable {
    var servers: [ServerModel]
    var version: String
}

extension ServersModel {
    
    enum ServersModelKeys: String, CodingKey {
        case servers = "server_list"
        case version = "v"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: ServersModelKeys.self)
        let servers = try container.decode([ServerModel].self, forKey: .servers)
        let version = try container.decode(String.self, forKey: .version)

        self.init(servers: servers, version: version)
    }
}

struct ServerModel: Decodable {
    
    let providerType: ProviderType = .organization
    var baseUri: URL
    var peers: [PeerModel]?
    
    var displayNames: [String: String]?
    var displayName: String?
      
    var logoUrls: [String: URL]?
    var logoUrl: URL?

}

extension ServerModel {
    
    enum ServerModelKeys: String, CodingKey {
        case baseUri = "base_url"
        case peers = "peer_list"
        case displayName = "display_name"
        case logoUrl = "logo_uri"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: ServerModelKeys.self)
        
        let baseUri = try container.decode(URL.self, forKey: .baseUri)
        
        let peers = try? container.decode(Array<PeerModel>.self, forKey: .peers)
        
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
                  peers: peers,
                  displayNames: displayNames,
                  displayName: displayName,
                  logoUrls: logoUrls,
                  logoUrl: logoUrl)
    }
}

struct PeerModel: Decodable {
    var baseUri: URL
    
    var displayNames: [String: String]?
    var displayName: String?
}

extension PeerModel {
    
    enum PeerModelKeys: String, CodingKey {
        case baseUri = "base_url"
        case displayName = "display_name"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: PeerModelKeys.self)
        
        let baseUri = try container.decode(URL.self, forKey: .baseUri)
        
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

        self.init(baseUri: baseUri,
                  displayNames: displayNames,
                  displayName: displayName)
    }
}
