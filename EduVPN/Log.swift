//
//  Log.swift
//  EduVPN
//
//  Created by Jeroen Leenarts on 07-07-18.
//  Copyright © 2018 SURFNet. All rights reserved.
//

import os.log

struct Log {
    static var general = OSLog(subsystem: "nl.eduvpn.app.EduVPN", category: "general")
    static var tunnel = OSLog(subsystem: "nl.eduvpn.app.EduVPN.EduVPNTunnelExtension", category: "tunnel extension")
}
