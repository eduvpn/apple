//
//  Server+CoreDataProperties.swift
//

import Foundation
import CoreData

extension Server {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Server> {
        return NSFetchRequest<Server>(entityName: "Server")
    }

    @NSManaged public var available: Bool
    @NSManaged public var baseURI: URL?
    @NSManaged public var displayName: String?
    @NSManaged public var isExpanded: Bool
    @NSManaged public var isParent: Bool
    @NSManaged public var lastAccessed: Date?
    @NSManaged public var sortName: String?
    @NSManaged public var serverGroupURI: URL?
    @NSManaged public var children: Set<Server>?
    @NSManaged public var displayNames: Set<DisplayName>?
    @NSManaged public var parent: Server?
    @NSManaged public var profiles: Profile?
    @NSManaged public var provider: ManagedProvider?

}

// MARK: Generated accessors for children
extension Server {

    @objc(addChildrenObject:)
    @NSManaged public func addToChildren(_ value: Server)

    @objc(removeChildrenObject:)
    @NSManaged public func removeFromChildren(_ value: Server)

    @objc(addChildren:)
    @NSManaged public func addToChildren(_ values: NSSet)

    @objc(removeChildren:)
    @NSManaged public func removeFromChildren(_ values: NSSet)

}

// MARK: Generated accessors for displayNames
extension Server {

    @objc(addDisplayNamesObject:)
    @NSManaged public func addToDisplayNames(_ value: DisplayName)

    @objc(removeDisplayNamesObject:)
    @NSManaged public func removeFromDisplayNames(_ value: DisplayName)

    @objc(addDisplayNames:)
    @NSManaged public func addToDisplayNames(_ values: NSSet)

    @objc(removeDisplayNames:)
    @NSManaged public func removeFromDisplayNames(_ values: NSSet)

}
