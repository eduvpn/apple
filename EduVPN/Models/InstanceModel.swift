//
//  InstanceModel.swift
//  EduVPN
//
//  Created by Jeroen Leenarts on 04-08-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

import Foundation

enum AuthorizationType: String {
    case local
    case distributed
}

struct InstancesModel: JSONSerializable {
    var authorizationType: AuthorizationType
    var seq: Int
    var signedAt: Date
    var instances: [InstanceModel]

    init?(json: [String: Any]?) {
        guard let json = json else {
            return nil
        }

        guard let authorizationTypeString = json["authorization_type"] as? String, let authorizationType = AuthorizationType(rawValue: authorizationTypeString) else {
            return nil
        }

        guard let seq = json["seq"] as? Int else {
            return nil
        }

        guard let dateString = json["signed_at"] as? String, let signedAt = signedAtDateFormatter.date(from: dateString) else {
            return nil
        }

        guard let instances = json["instances"] as? [[String:AnyObject]] else {
            return nil
        }

        self.authorizationType = authorizationType
        self.seq = seq
        self.signedAt = signedAt
        self.instances = instances.flatMap { InstanceModel(json:$0) }
    }

    var jsonDictionary: [String: Any] {
        var json = [String: Any]()

        json["authorization_type"] = authorizationType.rawValue
        json["seq"] = seq
        json["signed_at"] = signedAtDateFormatter.string(from: signedAt)
        json["instances"] = self.instances.map({$0.jsonDictionary})

        return json
    }
}

struct InstanceModel: JSONSerializable {
    var providerType: ProviderType = .unknown
    var baseUri: URL
    var displayNames: [String: String]?
    var logoUrlStrings: [String: String]?

    var displayName: String?
    var logoUrl: URL?

    init?(json: [String: AnyObject]?) {
        guard let json = json else {
            return nil
        }

        guard let baseUriString = json["base_uri"] as? String, let baseUri = URL(string: baseUriString) else {
            return nil
        }

        if let displayName = json["display_name"] as? String {
            self.displayName = displayName
        } else if let displayNames = json["display_name"] as? [String: String] {
            self.displayNames = displayNames
            let preferedLocalization = Bundle.preferredLocalizations(from: Array(displayNames.keys))
            for localeIdentifier in preferedLocalization {
                if let displayNameCandidate = displayNames[localeIdentifier] {
                    displayName = displayNameCandidate
                    break
                }
            }
        } else {
            return nil
        }

        if let logoUrlString = json["logo"] as? String {
            logoUrl = URL(string: logoUrlString)
        } else if let logoUrlStrings = json["logo"] as? [String: String] {
            self.logoUrlStrings = logoUrlStrings
            let preferedLocalization = Bundle.preferredLocalizations(from: Array(logoUrlStrings.keys))
            for localeIdentifier in preferedLocalization {
                if let logoUrlStringCandidate = logoUrlStrings[localeIdentifier] {
                    logoUrl = URL(string: logoUrlStringCandidate)
                    break
                }
            }
        } else {
            return nil
        }

        self.baseUri = baseUri
    }

    var jsonDictionary: [String: Any] {
        var json = [String: Any]()

        json["base_uri"] = baseUri.absoluteString
        if let displayNames = displayNames {
            json["display_name"] = displayNames
        } else {
            json["display_name"] = displayName
        }

        if let logoUrlStrings = logoUrlStrings {
            json["logo"] = logoUrlStrings
        }

        return json
    }
}
