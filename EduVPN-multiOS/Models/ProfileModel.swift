//
//  ProfileModel.swift
//  eduVPN
//
//  Created by Jeroen Leenarts on 21-08-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

import Foundation

struct ProfilesModel: Decodable {
    
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
}

struct InstanceProfileModel: Decodable {
    
    var displayNames: [String: String]?
    
    var displayName: String?
    var profileId: String
    let twoFactor: Bool
    var instanceApiBaseUrl: URL?
    var info: InstanceModel!
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
            displayName = try container.decode(String.self, forKey: .displayName)
        }
        
        let twoFactor = try container.decodeIfPresent(Bool.self, forKey: .twoFactor) ?? false
        
        self.init(displayNames: displayNames,
                  displayName: displayName,
                  profileId: profileId,
                  twoFactor: twoFactor,
                  instanceApiBaseUrl: nil,
                  info: nil)
    }
}

extension InstanceProfileModel: Hashable {
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(profileId)
    }
    
    static func == (lhs: InstanceProfileModel, rhs: InstanceProfileModel) -> Bool {
        return lhs.profileId == rhs.profileId && lhs.instanceApiBaseUrl == rhs.instanceApiBaseUrl
    }
}
