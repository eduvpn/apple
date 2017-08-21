//
//  UserDefaults+EduVPN.swift
//  EduVPN
//
//  Created by Jeroen Leenarts on 21-08-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

import Foundation

private let forceTcpDefaultsKey = "nl.eduvpn.app.forceTcp"

extension UserDefaults {
    var forceTcp: Bool {
        get {
            return UserDefaults.standard.bool(forKey: forceTcpDefaultsKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: forceTcpDefaultsKey)
        }
    }
}
