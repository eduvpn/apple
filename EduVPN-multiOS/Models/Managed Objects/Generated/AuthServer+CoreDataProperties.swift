//
//  AuthServer+CoreDataProperties.swift
//  eduVPN
//
//

import Foundation
import CoreData

extension AuthServer {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<AuthServer> {
        return NSFetchRequest<AuthServer>(entityName: "AuthServer")
    }

    @NSManaged public var authorizationEndpoint: String?
    @NSManaged public var tokenEndpoint: String?
    @NSManaged public var apis: Set<Api>?
    @NSManaged public var instances: Set<Instance>?

}

// MARK: Generated accessors for apis
extension AuthServer {

    @objc(addApisObject:)
    @NSManaged public func addToApis(_ value: Api)

    @objc(removeApisObject:)
    @NSManaged public func removeFromApis(_ value: Api)

    @objc(addApis:)
    @NSManaged public func addToApis(_ values: NSSet)

    @objc(removeApis:)
    @NSManaged public func removeFromApis(_ values: NSSet)

}

// MARK: Generated accessors for instances
extension AuthServer {

    @objc(addInstancesObject:)
    @NSManaged public func addToInstances(_ value: Instance)

    @objc(removeInstancesObject:)
    @NSManaged public func removeFromInstances(_ value: Instance)

    @objc(addInstances:)
    @NSManaged public func addToInstances(_ values: NSSet)

    @objc(removeInstances:)
    @NSManaged public func removeFromInstances(_ values: NSSet)

}
