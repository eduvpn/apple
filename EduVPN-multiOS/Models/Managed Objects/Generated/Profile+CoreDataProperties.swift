//
//  Profile+CoreDataProperties.swift
//  eduVPN
//
//  Created by Jeroen Leenarts on 11/04/2019.
//  Copyright © 2020 SURFNet. All rights reserved.
//
//

import Foundation
import CoreData

extension Profile {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Profile> {
        return NSFetchRequest<Profile>(entityName: "Profile")
    }

    @NSManaged public var uuid: UUID?
    @NSManaged public var profileId: String?
    @NSManaged public var rawVpnStatus: Int32
    @NSManaged public var api: Api?
    @NSManaged public var displayNames: Set<DisplayName>?

}

// MARK: Generated accessors for displayNames
extension Profile {

    @objc(addDisplayNamesObject:)
    @NSManaged public func addToDisplayNames(_ value: DisplayName)

    @objc(removeDisplayNamesObject:)
    @NSManaged public func removeFromDisplayNames(_ value: DisplayName)

    @objc(addDisplayNames:)
    @NSManaged public func addToDisplayNames(_ values: NSSet)

    @objc(removeDisplayNames:)
    @NSManaged public func removeFromDisplayNames(_ values: NSSet)

}
