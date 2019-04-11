//
//  Profile+Helper.swift
//  eduVPN
//
//  Created by Jeroen Leenarts on 19-02-18.
//  Copyright © 2018 SURFNet. All rights reserved.
//

import Foundation
import CoreData
import NetworkExtension

extension Profile {
    var displayString: String? {
        return api?.instance?.displayNames?.localizedValue ?? api?.instance?.baseUri
    }

    static func upsert(with profileModels: [InstanceProfileModel], for api: Api, on context: NSManagedObjectContext) {
        // Key new models on profile ID.
        var keyedModels = profileModels.reduce([String: InstanceProfileModel]()) { (dict, model) -> [String: InstanceProfileModel] in
            var dict = dict
            dict[model.profileId] = model
            return dict
        }

        if let api = context.object(with: api.objectID) as? Api {
            api.profiles.forEach {
                let profileId = $0.profileId!
                if let model = keyedModels.removeValue(forKey: profileId) {
                    // Update existing models
                    $0.update(with: model)
                } else {
                    // Delete existing models that are "obsolete".
                    context.delete($0)
                }
            }

            // Insert new models
            keyedModels.values.forEach { (newModel) in
                let newProfile = Profile(context: context)
                newProfile.update(with: newModel)
                newProfile.uuid = UUID()
                newProfile.api = api
            }
        }
    }

    func update(with profileModel: InstanceProfileModel) {
        self.profileId = profileModel.profileId

        if let displayNames = profileModel.displayNames {
            self.displayNames = Set(displayNames.compactMap({ (displayData) -> DisplayName? in
                let displayName = DisplayName(context: self.managedObjectContext!)
                displayName.locale = displayData.key
                displayName.displayName = displayData.value
                displayName.profile = self
                return displayName
            }))
        } else if let displayNameString = profileModel.displayName {
            let displayName = DisplayName(context: self.managedObjectContext!)
            displayName.displayName = displayNameString
            displayName.profile = self
        } else {
            self.displayNames = []
        }
    }

    var isActiveConfig: Bool {
         guard let configuredProfileId = UserDefaults.standard.configuredProfileId else { return false}
        return configuredProfileId == uuid?.uuidString
    }

    var vpnStatus: NEVPNStatus {
        get {
            return NEVPNStatus(rawValue: Int(rawVpnStatus)) ?? NEVPNStatus.invalid
        }
        set {
            rawVpnStatus = Int32(newValue.rawValue)
        }
    }
}
