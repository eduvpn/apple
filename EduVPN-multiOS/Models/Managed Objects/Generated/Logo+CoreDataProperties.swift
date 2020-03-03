//
//  Logo+CoreDataProperties.swift
//  eduVPN
//
//

import Foundation
import CoreData

extension Logo {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Logo> {
        return NSFetchRequest<Logo>(entityName: "Logo")
    }

    @NSManaged public var locale: String?
    @NSManaged public var logo: String?
    @NSManaged public var instance: Instance?

}
