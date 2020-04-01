//
//  Custom.swift
//  EduVPN
//
//  Created by Johan Kool on 31/03/2020.
//  Copyright © 2020 SURFNet. All rights reserved.
//

import Foundation

extension Custom {
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        groupName = NSLocalizedString("Custom", comment: "")
    }
    
    override public func awakeFromFetch() {
        super.awakeFromFetch()
        groupName = NSLocalizedString("Custom", comment: "")
    }
    
}
