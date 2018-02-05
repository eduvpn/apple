//
//  InstanceGroup+CoreDataProperties.swift
//  EduVPN
//
//  Created by Jeroen Leenarts on 08-02-18.
//  Copyright © 2018 SURFNet. All rights reserved.
//
//

import Foundation
import CoreData

extension InstanceGroup {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<InstanceGroup> {
        return NSFetchRequest<InstanceGroup>(entityName: "InstanceGroup")
    }

    @NSManaged public var discoveryIdentifier: String?
    @NSManaged public var providerType: String?
    @NSManaged public var instances: Set<Instance>

}

// MARK: Generated accessors for instances
extension InstanceGroup {

    @objc(addInstancesObject:)
    @NSManaged public func addToInstances(_ value: Instance)

    @objc(removeInstancesObject:)
    @NSManaged public func removeFromInstances(_ value: Instance)

    @objc(addInstances:)
    @NSManaged public func addToInstances(_ values: NSSet)

    @objc(removeInstances:)
    @NSManaged public func removeFromInstances(_ values: NSSet)

}
