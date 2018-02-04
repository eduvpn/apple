//
//  Profile+CoreDataProperties.swift
//  EduVPN
//
//  Created by Jeroen Leenarts on 04-02-18.
//  Copyright © 2018 SURFNet. All rights reserved.
//
//

import Foundation
import CoreData

extension Profile {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Profile> {
        return NSFetchRequest<Profile>(entityName: "Profile")
    }

    @NSManaged public var profileId: String?
    @NSManaged public var twoFactor: Bool
    @NSManaged public var api: Api?
    @NSManaged public var displayNames: DisplayName?

}
