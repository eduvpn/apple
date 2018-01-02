//
//  ProfileModel.swift
//  EduVPN
//
//  Created by Jeroen Leenarts on 21-08-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

import Foundation

struct ProfilesModel: Codable {
    var profiles: [InstanceProfileModel]
}

extension ProfilesModel {
    enum ProfilesModelKeys: String, CodingKey {
        case profileList = "profile_list"
        case data
        case profiles
        case instanceInfo = "instance_info"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: ProfilesModelKeys.self)

        let profileListContainer = try container.nestedContainer(keyedBy: ProfilesModelKeys.self, forKey: .profileList)
        let profiles = try profileListContainer.decode([InstanceProfileModel].self, forKey: .data)

        self.init(profiles: profiles)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: ProfilesModelKeys.self)

        var profileList = container.nestedContainer(keyedBy: ProfilesModelKeys.self, forKey: .profileList)
        try profileList.encode(profiles, forKey: .data)
    }

}

struct InstanceProfileModel: Codable {
    var displayNames: [String: String]?

    var displayName: String?
    var profileId: String
    var twoFactor: Bool
}

extension InstanceProfileModel {
    enum InstanceProfileModelKeys: String, CodingKey {
        case displayName = "display_name"
        case profileId = "profile_id"
        case twoFactor = "two_factor"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: InstanceProfileModelKeys.self)

        let profileId = try container.decode(String.self, forKey: .profileId)
        let twoFactor = try container.decode(Bool.self, forKey: .twoFactor)

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

        self.init(displayNames: displayNames, displayName: displayName, profileId: profileId, instanceApiBaseUrl: nil, twoFactor: twoFactor)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: InstanceProfileModelKeys.self)
        try container.encode(profileId, forKey: .profileId)
        try container.encode(twoFactor, forKey: .twoFactor)

        if let displayNames = displayNames {
            try container.encodeIfPresent(displayNames, forKey: .displayName)
        } else {
            try container.encodeIfPresent(displayName, forKey: .displayName)
        }
    }

}

extension InstanceProfileModel: Hashable {
    var hashValue: Int {
        return profileId.hashValue
    }

    static func == (lhs: InstanceProfileModel, rhs: InstanceProfileModel) -> Bool {
        return lhs.profileId == rhs.profileId
    }
}
