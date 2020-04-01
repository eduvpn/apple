//
//  Provider+CoreDataProperties.swift
//
//

import Foundation
import CoreData

extension Provider {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Provider> {
        return NSFetchRequest<Provider>(entityName: "Provider")
    }

    @NSManaged public var groupName: String?
      
}
