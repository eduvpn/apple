//
//  Organization.swift
//  EduVPN
//
//  Created by Johan Kool on 12/03/2020.
//  Copyright © 2020 SURFNet. All rights reserved.
//

import Foundation
import CoreData

extension Organization {
    
    var displayName: String {
        return displayNames?.localizedValue ?? baseUri ?? ""
    }
    
    func update(with model: OrganizationModel) {
        guard let managedObjectContext = self.managedObjectContext else {
            return
        }
        self.baseUri = model.infoUri.absoluteString
        self.displayNames?.forEach { managedObjectContext.delete($0) }
        
        if let displayNames = model.displayNames {
            self.displayNames = Set(displayNames.compactMap { (displayData) -> DisplayName? in
                let displayName = DisplayName(context: managedObjectContext)
                displayName.locale = displayData.key
                displayName.displayName = displayData.value
                displayName.organization = self
                return displayName
            })
        } else if let displayNameString = model.displayName {
            let displayName = DisplayName(context: managedObjectContext)
            displayName.displayName = displayNameString
            displayName.organization = self
        } else {
            self.displayNames = []
        }
    }
}
