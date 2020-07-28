//
//  UserDefaults+Preferences.swift
//  EduVPN
//

import Foundation

extension UserDefaults {

    private static let forceTCPDefaultsKey = "force_tcp"

    var forceTCP: Bool {
        get { // swiftlint:disable:this implicit_getter
            return bool(forKey: Self.forceTCPDefaultsKey)
        }
        set {
            set(newValue, forKey: Self.forceTCPDefaultsKey)
        }
    }
}
