//
//  Organization+CoreDataProperties.swift
//

import Foundation
import CoreData

extension Organization {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Organization> {
        return NSFetchRequest<Organization>(entityName: "Organization")
    }

    @NSManaged public var displayName: String?
    @NSManaged public var identifier: String?
    @NSManaged public var keyword: String?
    @NSManaged public var serverListUri: URL?
    @NSManaged public var version: String?
    @NSManaged public var displayNames: Set<DisplayName>?
    @NSManaged public var keywords: Set<Keywords>?
    @NSManaged public var organizationList: OrganizationList?

}

// MARK: Generated accessors for displayNames
extension Organization {

    @objc(addDisplayNamesObject:)
    @NSManaged public func addToDisplayNames(_ value: DisplayName)

    @objc(removeDisplayNamesObject:)
    @NSManaged public func removeFromDisplayNames(_ value: DisplayName)

    @objc(addDisplayNames:)
    @NSManaged public func addToDisplayNames(_ values: NSSet)

    @objc(removeDisplayNames:)
    @NSManaged public func removeFromDisplayNames(_ values: NSSet)

}

// MARK: Generated accessors for keywords
extension Organization {

    @objc(addKeywordsObject:)
    @NSManaged public func addToKeywords(_ value: Keywords)

    @objc(removeKeywordsObject:)
    @NSManaged public func removeFromKeywords(_ value: Keywords)

    @objc(addKeywords:)
    @NSManaged public func addToKeywords(_ values: NSSet)

    @objc(removeKeywords:)
    @NSManaged public func removeFromKeywords(_ values: NSSet)

}
