//
//  DisplayName+CoreDataProperties.swift
//  EduVPN
//
//  Created by Jeroen Leenarts on 04-02-18.
//  Copyright © 2018 SURFNet. All rights reserved.
//
//

import Foundation
import CoreData

extension DisplayName {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<DisplayName> {
        return NSFetchRequest<DisplayName>(entityName: "DisplayName")
    }

    @NSManaged public var displayName: String?
    @NSManaged public var locale: String?
    @NSManaged public var instance: Instance?
    @NSManaged public var profile: Profile?

}
