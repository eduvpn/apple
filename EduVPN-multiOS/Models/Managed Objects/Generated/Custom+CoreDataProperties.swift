//
//  Custom+CoreDataProperties.swift
//

import Foundation
import CoreData

extension Custom {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Custom> {
        return NSFetchRequest<Custom>(entityName: "Custom")
    }

}
