//
//  InstanceModel.swift
//  eduVPN
//
//  Created by Jeroen Leenarts on 04-08-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

import Foundation

enum InstancesModelError: Swift.Error {
    case signedAtDate
}

enum AuthorizationType: String, Decodable {
    case local
    case distributed
    case federated
}

struct InstancesModel: Decodable {
    var providerType: ProviderType
    var authorizationType: AuthorizationType
    var seq: Int
    var signedAt: Date?
    var instances: [InstanceModel]

    var authorizationEndpoint: URL?
    var tokenEndpoint: URL?
}

extension InstancesModel {
    
    enum InstancesModelKeys: String, CodingKey {
        case providerType = "provider_type"
        case authorizationType = "authorization_type"
        case authorizationEndpoint = "authorization_endpoint"
        case tokenEndpoint = "token_endpoint"
        case seq
        case signedAt = "signed_at"
        case instances
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: InstancesModelKeys.self)

        let providerType = try container.decodeIfPresent(ProviderType.self, forKey: .providerType) ?? .unknown

        let authorizationEndpoint = try container.decodeIfPresent(URL.self, forKey: .authorizationEndpoint)
        let tokenEndpoint = try container.decodeIfPresent(URL.self, forKey: .tokenEndpoint)

        let authorizationType = try container.decode(AuthorizationType.self, forKey: .authorizationType)
        let seq = try container.decode(Int.self, forKey: .seq)
        var signedAt: Date?
        if let signedAtString = try container.decodeIfPresent(String.self, forKey: .signedAt) {
            signedAt = signedAtDateFormatter.date(from: signedAtString)
        }

        let instances = try container.decode([InstanceModel].self, forKey: .instances)
        self.init(providerType: providerType,
                  authorizationType: authorizationType,
                  seq: seq,
                  signedAt: signedAt,
                  instances: instances,
                  authorizationEndpoint: authorizationEndpoint,
                  tokenEndpoint: tokenEndpoint)
    }
}

struct InstanceModel: Decodable {
    
    var providerType: ProviderType
    var baseUri: URL
    var displayNames: [String: String]?
    var logoUrls: [String: URL]?

    var displayName: String?
    var logoUrl: URL?
}

extension InstanceModel {
    
    enum InstanceModelKeys: String, CodingKey {
        case providerType = "provider_type"
        case baseUri = "base_uri"
        case displayName = "display_name"
        case logo = "logo"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: InstanceModelKeys.self)

        let baseUri = try container.decode(URL.self, forKey: .baseUri)
        let providerType = try container.decodeIfPresent(ProviderType.self, forKey: .providerType) ?? .unknown

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
        let logoUrls: [String: URL]? = try? container.decode([String: URL].self, forKey: .logo)

        if let logoUrls = logoUrls {
            let preferedLocalization = Bundle.preferredLocalizations(from: Array(logoUrls.keys))
            for localeIdentifier in preferedLocalization {
                if let logoUrlCandidate = logoUrls[localeIdentifier] {
                    logoUrl = logoUrlCandidate
                    break
                }
            }
        } else {
            logoUrl = try container.decodeIfPresent(URL.self, forKey: .logo)
        }

        self.init(providerType: providerType,
                  baseUri: baseUri,
                  displayNames: displayNames,
                  logoUrls: logoUrls,
                  displayName: displayName,
                  logoUrl: logoUrl)
    }
}
