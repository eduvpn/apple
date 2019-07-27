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
        return createLog(with: "general")
    }()

    static var crypto: OSLog = {
        return createLog(with: "crypto")
    }()

    private static func createLog(with category: String) -> OSLog {
        if let bundleID = Bundle.main.bundleIdentifier {
            return OSLog(subsystem: bundleID, category: category)
        } else {
            fatalError("missing bundle ID")
        }
    }
}
