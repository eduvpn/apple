//
//  Api+CoreDataProperties.swift
//  EduVPN
//
//  Created by Jeroen Leenarts on 04-02-18.
//  Copyright © 2018 SURFNet. All rights reserved.
//
//

import Foundation
import CoreData

import AppAuth
import KeychainSwift

extension Api {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Api> {
        return NSFetchRequest<Api>(entityName: "Api")
    }

    @NSManaged public var apiBaseUri: String?
    @NSManaged public var authorizationEndpoint: String?
    @NSManaged public var tokenEndpoint: String?
    @NSManaged public var instance: Instance?
    @NSManaged public var profiles: Set<Profile>

    private var keychainKey: String {
        return "\(authorizationEndpoint!)|instance-info-authState"
    }

    var authState: OIDAuthState? {
        get {
            if let data = KeychainSwift().getData(keychainKey) {
                return NSKeyedUnarchiver.unarchiveObject(with: data) as? OIDAuthState
            } else {
                return nil
            }
        }
        set {
            if let newValue = newValue {
                let data = NSKeyedArchiver.archivedData(withRootObject: newValue)
                KeychainSwift().set(data, forKey: keychainKey)
            } else {
                KeychainSwift().delete(keychainKey)
            }
        }
    }

}

// MARK: Generated accessors for profiles
extension Api {

    @objc(addProfilesObject:)
    @NSManaged public func addToProfiles(_ value: Profile)

    @objc(removeProfilesObject:)
    @NSManaged public func removeFromProfiles(_ value: Profile)

    @objc(addProfiles:)
    @NSManaged public func addToProfiles(_ values: NSSet)

    @objc(removeProfiles:)
    @NSManaged public func removeFromProfiles(_ values: NSSet)

}
