//
//  UserDefaults+EduVPN.swift
//  EduVPN
//
//  Created by Jeroen Leenarts on 21-08-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

import Foundation

private let forceTcpDefaultsKey = "force_tcp"
private let configuredProfileUuidKey = "configured_profile_uuid"

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
            return self.string(forKey: configuredProfileUuidKey)
        }
        set {
            self.set(newValue, forKey: configuredProfileUuidKey)
        }
    }
}
