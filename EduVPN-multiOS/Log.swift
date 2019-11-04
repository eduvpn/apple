//
//  Log.swift
//  eduVPN
//
//  Created by Jeroen Leenarts on 07-07-18.
//  Copyright © 2018 SURFNet. All rights reserved.
//

import Foundation
import os.log

struct Log {
    
    static var general: OSLog = {
        if let bundleID = Bundle.main.bundleIdentifier {
            return OSLog(subsystem: bundleID, category: "general")
        } else {
            fatalError("missing bundle ID")
        }
    }()

    static var crypto: OSLog = {
        if let bundleID = Bundle.main.bundleIdentifier {
            return OSLog(subsystem: bundleID, category: "crypto")
        } else {
            fatalError("missing bundle ID")
        }
    }()

    static var auth: OSLog = {
        if let bundleID = Bundle.main.bundleIdentifier {
            return OSLog(subsystem: bundleID, category: "auth")
        } else {
            fatalError("missing bundle ID")
        }
    }()

}
