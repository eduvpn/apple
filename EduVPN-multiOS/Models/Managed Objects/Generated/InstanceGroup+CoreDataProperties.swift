//
//  InstanceGroup+CoreDataProperties.swift
//  eduVPN
//
//

import Foundation
import CoreData

extension InstanceGroup {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<InstanceGroup> {
        return NSFetchRequest<InstanceGroup>(entityName: "InstanceGroup")
    }

//    var authorizationTypeEnum: AuthorizationType {
//        guard let authorizationTypeString = authorizationType else { return .local }
//        return AuthorizationType(rawValue: authorizationTypeString) ?? .local
//    }

    @NSManaged public var discoveryIdentifier: String?
    @NSManaged public var authorizationType: String?
    @NSManaged public var instances: Set<Instance>
    @NSManaged public var seq: Int32

    @NSManaged public var distributedAuthorizationApi: Api?

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
