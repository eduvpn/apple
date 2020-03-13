//
//  Keywords+CoreDataProperties.swift
//
//
import Foundation
import CoreData


extension Keywords {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Keywords> {
        return NSFetchRequest<Keywords>(entityName: "Keywords")
    }

    @NSManaged public var keywords: String?
    @NSManaged public var locale: String?
    @NSManaged public var organization: Organization?

}
