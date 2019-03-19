//
//  AuthServer+CoreDataProperties.swift
//  eduVPN
//
//  Created by Jeroen Leenarts on 25-02-18.
//  Copyright © 2018 SURFNet. All rights reserved.
//
//

import Foundation
import CoreData

extension AuthServer {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<AuthServer> {
        return NSFetchRequest<AuthServer>(entityName: "AuthServer")
    }

    @NSManaged public var tokenEndpoint: String?
    @NSManaged public var authorizationEndpoint: String?
    @NSManaged public var apis: NSSet?
    @NSManaged public var instances: NSSet?

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
