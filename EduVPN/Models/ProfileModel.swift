//
//  ProfileModel.swift
//  EduVPN
//
//  Created by Jeroen Leenarts on 21-08-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

import Foundation

struct ProfilesModel {
    var instanceInfo: InstanceInfoModel?
    var profiles: [ProfileModel]

    init?(json: [String: Any]?) {
        guard let json = json else {
            return nil
        }

        guard let profileList = json["profile_list"] as? [String: Any] else {
            return nil
        }

        guard let profiles = profileList["data"] as? [[String: Any]] else {
            return nil
        }

        self.profiles = profiles.flatMap({ ProfileModel(json:$0) })
    }

    var jsonDictionary: [String: Any] {
        var json = [String: Any]()

        json["profile_list"] = ["data": self.profiles.map({$0.jsonDictionary})]

        return json
    }

}

struct ProfileModel {
    var displayNames: [String: String]?

    var displayName: String?
    var profileId: String
    var twoFactor: Bool

    init?(json: [String: Any]?) {
        guard let json = json else {
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

        guard let profileId = json["profile_id"] as? String else {
            return nil
        }

        guard let twoFactor = json["two_factor"] as? Bool else {
            return nil
        }

        self.profileId = profileId
        self.twoFactor = twoFactor

    }

    var jsonDictionary: [String: Any] {
        var json = [String: Any]()

        if let displayNames = displayNames {
            json["display_name"] = displayNames
        } else {
            json["display_name"] = displayName
        }

        json["profile_id"] = profileId
        json["two_factor"] = twoFactor

        return json
    }
}

extension ProfileModel: Hashable {
    var hashValue: Int {
        return profileId.hashValue
    }

    static func == (lhs: ProfileModel, rhs: ProfileModel) -> Bool {
        return lhs.profileId == rhs.profileId
    }
}
