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
}

struct InstancesModel: JSONSerializable {
    var authorizationType: AuthorizationType
    var seq: Int
    var signedAt: Date
    var version: Int
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

        guard let version = json["version"] as? Int else {
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
        self.version = version
        self.instances = instances.flatMap { InstanceModel(json:$0) }
    }

    var jsonDictionary: [String: Any] {
        var json = [String: Any]()

        json["authorization_type"] = authorizationType.rawValue
        json["seq"] = version
        json["version"] = version
        json["signed_at"] = signedAtDateFormatter.string(from: signedAt)
        json["instances"] = self.instances.map({$0.jsonDictionary})

        return json
    }
}

struct InstanceModel: JSONSerializable {
    var baseUri: URL
    var displayName: String
    var logoUri: URL

    init?(json: [String: AnyObject]?) {
        guard let json = json else {
            return nil
        }

        guard let baseUriString = json["base_uri"] as? String, let baseUri = URL(string: baseUriString) else {
            return nil
        }
        guard let displayName = json["display_name"] as? String else {
            return nil
        }

        guard let logoUriString = json["logo_uri"] as? String, let logoUri = URL(string: logoUriString) else {
            return nil
        }

        self.baseUri = baseUri
        self.displayName = displayName
        self.logoUri = logoUri
    }

    var jsonDictionary: [String: Any] {
        var json = [String: Any]()

        json["base_uri"] = baseUri.absoluteString
        json["display_name"] = displayName
        json["logo_uri"] = logoUri.absoluteString

        return json
    }
}
