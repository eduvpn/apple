//
//  InstanceModel.swift
//  EduVPN
//
//  Created by Jeroen Leenarts on 04-08-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

import Foundation

enum InstancesModelError: Swift.Error {
    case signedAtDate
}

enum AuthorizationType: String, Codable {
    case local
    case distributed
}

struct InstancesModel: Codable {
    var providerType: ProviderType?
    var authorizationType: AuthorizationType
    var seq: Int
    var signedAt: Date
    var instances: [InstanceModel]
}

extension InstancesModel {
    enum InstancesModelKeys: String, CodingKey {
        case providerType = "provider_type"
        case authorizationType = "authorization_type"
        case seq
        case signedAt = "signed_at"
        case instances
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: InstancesModelKeys.self)

        let providerType = try container.decodeIfPresent(ProviderType.self, forKey: .providerType)
        let authorizationType = try container.decode(AuthorizationType.self, forKey: .authorizationType)
        let seq = try container.decode(Int.self, forKey: .seq)
        let signedAtString = try container.decode(String.self, forKey: .signedAt)
        guard let signedAt = signedAtDateFormatter.date(from: signedAtString) else {
            throw InstancesModelError.signedAtDate
        }

        let instances = try container.decode([InstanceModel].self, forKey: .instances)
        self.init(providerType: providerType, authorizationType: authorizationType, seq: seq, signedAt: signedAt, instances: instances)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: InstancesModelKeys.self)
        try container.encodeIfPresent(providerType, forKey: .providerType)
        try container.encode(authorizationType, forKey: .authorizationType)
        try container.encode(seq, forKey: .seq)
        let signedAtString = signedAtDateFormatter.string(from: signedAt)
        try container.encode(signedAtString, forKey: .signedAt)
        try container.encode(instances, forKey: .instances)
    }
}

struct InstanceModel: Codable {
    var providerType: ProviderType
    var baseUri: URL
    var displayNames: [String: String]?
    var logoUrls: [String: URL]?

    var instanceInfo: InstanceInfoModel?

    var displayName: String?
    var logoUrl: URL?
}

extension InstanceModel {
    enum InstanceModelKeys: String, CodingKey {
        case instanceInfo = "instance_info"
        case providerType = "provider_type"
        case baseUri = "base_uri"
        case displayName = "display_name"
        case logo = "logo"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: InstanceModelKeys.self)

        let instanceInfo = try? container.decode(InstanceInfoModel.self, forKey: .instanceInfo)

        let baseUri = try container.decode(URL.self, forKey: .baseUri)
        let providerType = try container.decodeIfPresent(ProviderType.self, forKey: .providerType) ?? .unknown

        var displayName: String? = nil
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
            displayName = try container.decode(String.self, forKey: .displayName)
        }

        var logoUrl: URL? = nil
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
            logoUrl = try container.decode(URL.self, forKey: .logo)
        }

        self.init(providerType: providerType, baseUri: baseUri, displayNames: displayNames, logoUrls: logoUrls, instanceInfo: instanceInfo, displayName: displayName, logoUrl: logoUrl)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: InstanceModelKeys.self)

        try container.encode(baseUri, forKey: .baseUri)
        try container.encodeIfPresent(providerType, forKey: .providerType)

        try container.encodeIfPresent(instanceInfo, forKey: .instanceInfo)

        if let displayNames = displayNames {
            try container.encodeIfPresent(displayNames, forKey: .displayName)
        } else {
            try container.encodeIfPresent(displayName, forKey: .displayName)
        }

        if let logoUrls = logoUrls {
            try container.encodeIfPresent(logoUrls, forKey: .logo)
        } else {
            try container.encodeIfPresent(logoUrl, forKey: .logo)
        }

    }
}
