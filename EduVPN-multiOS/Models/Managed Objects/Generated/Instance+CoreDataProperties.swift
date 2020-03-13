//
//  Instance+CoreDataProperties.swift
//  EduVPN
//
//

import Foundation
import CoreData

extension Instance {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Instance> {
        return NSFetchRequest<Instance>(entityName: "Instance")
    }

    @NSManaged public var available: Bool
    @NSManaged public var baseUri: String?
    @NSManaged public var lastAccessedTimeInterval: Double
    @NSManaged public var providerType: String?
    @NSManaged public var publicKey: String?
    @NSManaged public var serverGroupUri: UUID?
    @NSManaged public var apis: Set<Api>?
    @NSManaged public var authServer: AuthServer?
    @NSManaged public var children: Set<Instance>?
    @NSManaged public var displayNames: Set<DisplayName>?
    @NSManaged public var group: InstanceGroup?
    @NSManaged public var logos: Set<Logo>?
    @NSManaged public var parent: Instance?
    @NSManaged public var provider: ManagedProvider?

}

// MARK: Generated accessors for apis
extension Instance {

    @objc(addApisObject:)
    @NSManaged public func addToApis(_ value: Api)

    @objc(removeApisObject:)
    @NSManaged public func removeFromApis(_ value: Api)

    @objc(addApis:)
    @NSManaged public func addToApis(_ values: NSSet)

    @objc(removeApis:)
    @NSManaged public func removeFromApis(_ values: NSSet)

}

// MARK: Generated accessors for children
extension Instance {

    @objc(addChildrenObject:)
    @NSManaged public func addToChildren(_ value: Instance)

    @objc(removeChildrenObject:)
    @NSManaged public func removeFromChildren(_ value: Instance)

    @objc(addChildren:)
    @NSManaged public func addToChildren(_ values: NSSet)

    @objc(removeChildren:)
    @NSManaged public func removeFromChildren(_ values: NSSet)

}

// MARK: Generated accessors for displayNames
extension Instance {

    @objc(addDisplayNamesObject:)
    @NSManaged public func addToDisplayNames(_ value: DisplayName)

    @objc(removeDisplayNamesObject:)
    @NSManaged public func removeFromDisplayNames(_ value: DisplayName)

    @objc(addDisplayNames:)
    @NSManaged public func addToDisplayNames(_ values: NSSet)

    @objc(removeDisplayNames:)
    @NSManaged public func removeFromDisplayNames(_ values: NSSet)

}

// MARK: Generated accessors for logos
extension Instance {

    @objc(addLogosObject:)
    @NSManaged public func addToLogos(_ value: Logo)

    @objc(removeLogosObject:)
    @NSManaged public func removeFromLogos(_ value: Logo)

    @objc(addLogos:)
    @NSManaged public func addToLogos(_ values: NSSet)

    @objc(removeLogos:)
    @NSManaged public func removeFromLogos(_ values: NSSet)

}
