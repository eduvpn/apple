//
//  Local+CoreDataProperties.swift
//

import Foundation
import CoreData

extension Local {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Local> {
        return NSFetchRequest<Local>(entityName: "Local")
    }

    @NSManaged public var fileUri: URL?

}
