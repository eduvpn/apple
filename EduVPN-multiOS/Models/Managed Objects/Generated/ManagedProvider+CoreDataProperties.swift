//
//  ManagedProvider+CoreDataProperties.swift
//
//

import Foundation
import CoreData

extension ManagedProvider {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ManagedProvider> {
        return NSFetchRequest<ManagedProvider>(entityName: "ManagedProvider")
    }

    @NSManaged public var serverInfoUri: URL?
    @NSManaged public var servers: Set<Instance>?

}

// MARK: Generated accessors for servers
extension ManagedProvider {

    @objc(addServersObject:)
    @NSManaged public func addToServers(_ value: Instance)

    @objc(removeServersObject:)
    @NSManaged public func removeFromServers(_ value: Instance)

    @objc(addServers:)
    @NSManaged public func addToServers(_ values: NSSet)

    @objc(removeServers:)
    @NSManaged public func removeFromServers(_ values: NSSet)

}
