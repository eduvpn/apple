//
//  Logo+CoreDataProperties.swift
//  eduVPN
//
//  Created by Jeroen Leenarts on 04-02-18.
//  Copyright © 2018 SURFNet. All rights reserved.
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
