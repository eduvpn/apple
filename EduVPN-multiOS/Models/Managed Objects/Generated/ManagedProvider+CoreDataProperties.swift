//
//  ManagedProvider+CoreDataProperties.swift
//

import Foundation
import CoreData

extension ManagedProvider {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ManagedProvider> {
        return NSFetchRequest<ManagedProvider>(entityName: "ManagedProvider")
    }

    @NSManaged public var servers: Set<Server>?

}

// MARK: Generated accessors for servers
extension ManagedProvider {

    @objc(addServersObject:)
    @NSManaged public func addToServers(_ value: Server)

    @objc(removeServersObject:)
    @NSManaged public func removeFromServers(_ value: Server)

    @objc(addServers:)
    @NSManaged public func addToServers(_ values: NSSet)

    @objc(removeServers:)
    @NSManaged public func removeFromServers(_ values: NSSet)

}
