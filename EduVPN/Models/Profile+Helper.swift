//
//  Profile+Helper.swift
//  EduVPN
//
//  Created by Jeroen Leenarts on 19-02-18.
//  Copyright © 2018 SURFNet. All rights reserved.
//

import Foundation
import CoreData

extension Profile {
    func update(with profileModel: InstanceProfileModel) {
        self.profileId = profileModel.profileId
        self.twoFactor = profileModel.twoFactor
        if let displayNames = profileModel.displayNames {
            self.displayNames = Set(displayNames.compactMap({ (displayData) -> DisplayName? in
                let displayName = DisplayName(context: self.managedObjectContext!)
                displayName.locale = displayData.key
                displayName.displayName = displayData.value
                displayName.profile = self
                return displayName
            }))
        }
    }
}
