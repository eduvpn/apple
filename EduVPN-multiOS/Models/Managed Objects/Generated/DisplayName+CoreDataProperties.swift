//
//  DisplayName+CoreDataProperties.swift
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
    @NSManaged public var organization: Organization?
    @NSManaged public var profile: Profile?
    @NSManaged public var server: Server?

}
