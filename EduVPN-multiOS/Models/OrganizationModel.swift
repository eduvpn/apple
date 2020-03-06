//
//  OrganizationModel.swift
//  eduVPN
//

import Foundation

struct OrganizationsModel: Decodable {
    var organizations: [OrganizationModel]
}

extension OrganizationsModel {
    
    enum OrganizationsModelKeys: String, CodingKey {
        case organizations = "organization_list"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: OrganizationsModelKeys.self)
        
//        let providerType = try container.decodeIfPresent(ProviderType.self, forKey: .providerType) ?? .unknown
//
//        let authorizationEndpoint = try container.decodeIfPresent(URL.self, forKey: .authorizationEndpoint)
//        let tokenEndpoint = try container.decodeIfPresent(URL.self, forKey: .tokenEndpoint)
//
//        let authorizationType = try container.decode(AuthorizationType.self, forKey: .authorizationType)
//        let seq = try container.decode(Int.self, forKey: .seq)
//        var signedAt: Date?
//        if let signedAtString = try container.decodeIfPresent(String.self, forKey: .signedAt) {
//            signedAt = signedAtDateFormatter.date(from: signedAtString)
//        }
        
        let organizations = try container.decode([OrganizationModel].self, forKey: .organizations)
//        // Temporarily apply fields, which are required by macOS logic
//        organizations = organizations.map {
//            var model = $0
//            model.authorizationType = authorizationType
//            model.authorizationEndpoint = authorizationEndpoint
//            model.tokenEndpoint = tokenEndpoint
//
//            return model
//        }
//
        self.init(organizations: organizations)
                
    }
}

struct OrganizationModel: Decodable {
    
    var providerType: ProviderType
    var baseUri: URL
    var displayNames: [String: String]?
    
    var displayName: String?
    var logoUrl: URL?
    
//    var authorizationType: AuthorizationType!
//    var authorizationEndpoint: URL?
//    var tokenEndpoint: URL?
}

extension OrganizationModel {
    
    enum OrganizationModelKeys: String, CodingKey {
//        case providerType = "provider_type"
        case baseUri = "server_info_url"
        case displayName = "display_name"
        case logo = "logo"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: OrganizationModelKeys.self)
        
        let baseUri = try container.decode(URL.self, forKey: .baseUri)
//        let providerType = try container.decodeIfPresent(ProviderType.self, forKey: .providerType) ?? .unknown
        
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
        
        self.init(providerType: .unknown,
                  baseUri: baseUri,
                  displayNames: displayNames,
                  displayName: displayName)
    }
}
