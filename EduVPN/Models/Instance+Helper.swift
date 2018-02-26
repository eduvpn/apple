//
//  Instace+Helper.swift
//  EduVPN
//
//  Created by Jeroen Leenarts on 19-02-18.
//  Copyright © 2018 SURFNet. All rights reserved.
//

import Foundation
import CoreData

extension Instance {
    var authorizationTypeEnum: AuthorizationType {
        guard let authorizationTypeString = authorizationType else { return .local }
        return AuthorizationType(rawValue: authorizationTypeString) ?? .local
    }

    func update(with model: InstanceModel) {
        self.baseUri = model.baseUri.absoluteString
        self.displayNames?.forEach { self.managedObjectContext?.delete($0) }
        self.logos?.forEach { self.managedObjectContext?.delete($0) }

        if let logoUrls = model.logoUrls {
            self.logos = Set(logoUrls.flatMap({ (logoData) -> Logo? in
                let newLogo = Logo(context: self.managedObjectContext!)
                newLogo.locale = logoData.key
                newLogo.logo = logoData.value.absoluteString
                newLogo.instance = self
                return newLogo
            }))
        } else if let logoUrl = model.logoUrl {
            let newLogo = Logo(context: self.managedObjectContext!)
            newLogo.logo = logoUrl.absoluteString
            self.logos = Set([newLogo])
            newLogo.instance = self
        } else {
            self.logos = []
        }

        if let displayNames = model.displayNames {
            self.displayNames = Set(displayNames.flatMap({ (displayData) -> DisplayName? in
                let displayName = DisplayName(context: self.managedObjectContext!)
                displayName.locale = displayData.key
                displayName.displayName = displayData.value
                displayName.instance = self
                return displayName
            }))
        } else if let displayNameString = model.displayName {
            let displayName = DisplayName(context: self.managedObjectContext!)
            displayName.displayName = displayNameString
            displayName.instance = self
        } else {
            self.displayNames = []
        }
    }

}
