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
    
    override public func awakeFromFetch() {
        super.awakeFromFetch()
        displayName = displayNames?.localizedValue
        keyword = keywords?.localizedValue
    }
    
    func update(with model: OrganizationModel) {
        guard let managedObjectContext = self.managedObjectContext else {
            return
        }
        self.identifier = model.identifier
        self.serverListUri = model.serverList
        
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
        
        displayName = displayNames?.localizedValue
        
        self.keywords?.forEach { managedObjectContext.delete($0) }
        
        if let keywordList = model.keywordLists {
            self.keywords = Set(keywordList.compactMap { (displayData) -> Keywords? in
                let keywords = Keywords(context: managedObjectContext)
                keywords.locale = displayData.key
                keywords.keywords = displayData.value
                keywords.organization = self
                return keywords
            })
        } else if let keywordList = model.keywordList {
            let keywords = Keywords(context: managedObjectContext)
            keywords.keywords = keywordList
            keywords.organization = self
        } else {
            self.keywords = []
        }
        
        keyword = keywords?.localizedValue
    }
}
