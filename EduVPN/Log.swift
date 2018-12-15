//
//  Log.swift
//  EduVPN
//
//  Created by Jeroen Leenarts on 07-07-18.
//  Copyright © 2018 SURFNet. All rights reserved.
//

import os.log

struct Log {
    //TODO: Dit baseren op PRODUCT_BUNDLE_IDENTIFIER
    static var general = OSLog(subsystem: "nl.eduvpn.app.EduVPN", category: "general")
    //TODO: Dit baseren op PRODUCT_BUNDLE_IDENTIFIER van extension
    static var tunnel = OSLog(subsystem: "nl.eduvpn.app.EduVPN.EduVPNTunnelExtension", category: "tunnel extension")
}
