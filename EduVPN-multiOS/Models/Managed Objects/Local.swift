//
//  Local.swift
//  EduVPN
//
//  Created by Johan Kool on 31/03/2020.
//  Copyright © 2020 SURFNet. All rights reserved.
//

import Foundation

extension Local {
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        groupName = NSLocalizedString("Local", comment: "")
    }
    
    override public func awakeFromFetch() {
        super.awakeFromFetch()
        groupName = NSLocalizedString("Local", comment: "")
    }

}
