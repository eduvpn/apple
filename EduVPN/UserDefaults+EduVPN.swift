//
//  UserDefaults+EduVPN.swift
//  EduVPN
//
//  Created by Jeroen Leenarts on 21-08-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

import Foundation

private let forceTcpDefaultsKey = "nl.eduvpn.app.forceTcp"
private let configuredProfileIdKey = "nl.eduvpn.app.configuredProfileIdKey"

extension UserDefaults {
    var forceTcp: Bool {
        get {
            return self.bool(forKey: forceTcpDefaultsKey)
        }
        set {
            self.set(newValue, forKey: forceTcpDefaultsKey)
        }
    }

    var configuredProfileId: String? {
        get {
            return self.string(forKey: configuredProfileIdKey)
        }
        set {
            self.set(newValue, forKey: configuredProfileIdKey)
        }
    }
}
