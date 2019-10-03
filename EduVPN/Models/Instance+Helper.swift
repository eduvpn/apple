//
//  Instace+Helper.swift
//  eduVPN
//
//  Created by Jeroen Leenarts on 19-02-18.
//  Copyright © 2018 SURFNet. All rights reserved.
//

import Foundation
import CoreData

extension Instance {
    func update(with model: InstanceModel) {
        guard let managedObjectContext = self.managedObjectContext else {
            return
        }
        self.baseUri = model.baseUri.absoluteString
        self.displayNames?.forEach { managedObjectContext.delete($0) }
        self.logos?.forEach { managedObjectContext.delete($0) }

        if let logoUrls = model.logoUrls {
            self.logos = Set(logoUrls.compactMap({ (logoData) -> Logo? in
                let newLogo = Logo(context: managedObjectContext)
                newLogo.locale = logoData.key
                newLogo.logo = logoData.value.absoluteString
                newLogo.instance = self
                return newLogo
            }))
        } else if let logoUrl = model.logoUrl {
            let newLogo = Logo(context: managedObjectContext)
            newLogo.logo = logoUrl.absoluteString
            self.logos = Set([newLogo])
            newLogo.instance = self
        } else {
            self.logos = []
        }

        if let displayNames = model.displayNames {
            self.displayNames = Set(displayNames.compactMap({ (displayData) -> DisplayName? in
                let displayName = DisplayName(context: managedObjectContext)
                displayName.locale = displayData.key
                displayName.displayName = displayData.value
                displayName.instance = self
                return displayName
            }))
        } else if let displayNameString = model.displayName {
            let displayName = DisplayName(context: managedObjectContext)
            displayName.displayName = displayNameString
            displayName.instance = self
        } else {
            self.displayNames = []
        }
    }

}
