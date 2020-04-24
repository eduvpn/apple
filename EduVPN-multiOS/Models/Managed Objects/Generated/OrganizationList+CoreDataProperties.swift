//
//  OrganizationList+CoreDataProperties.swift
//

import Foundation
import CoreData

extension OrganizationList {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<OrganizationList> {
        return NSFetchRequest<OrganizationList>(entityName: "OrganizationList")
    }

    @NSManaged public var version: String?
    @NSManaged public var organizations: Set<Organization>?

}

// MARK: Generated accessors for organizations
extension OrganizationList {

    @objc(addOrganizationsObject:)
    @NSManaged public func addToOrganizations(_ value: Organization)

    @objc(removeOrganizationsObject:)
    @NSManaged public func removeFromOrganizations(_ value: Organization)

    @objc(addOrganizations:)
    @NSManaged public func addToOrganizations(_ values: NSSet)

    @objc(removeOrganizations:)
    @NSManaged public func removeFromOrganizations(_ values: NSSet)

}
