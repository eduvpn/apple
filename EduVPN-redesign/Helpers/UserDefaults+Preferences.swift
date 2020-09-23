//
//  UserDefaults+Preferences.swift
//  EduVPN
//

import Foundation

extension UserDefaults {

    private static let forceTCPDefaultsKey = "force_tcp"
    private static let showInStatusBarKey = "showInStatusBar"
    private static let showInDockKey = "showInDock"
    private static let launchAtLoginKey = "launchAtLogin"

    private static let assistPathUpgradingWithPathMonitorKey = "assistPathUpgradingWithPathMonitor"

    var forceTCP: Bool {
        get { // swiftlint:disable:this implicit_getter
            return bool(forKey: Self.forceTCPDefaultsKey)
        }
        set {
            set(newValue, forKey: Self.forceTCPDefaultsKey)
        }
    }

    var showInStatusBar: Bool {
        get { // swiftlint:disable:this implicit_getter
            if object(forKey: Self.showInStatusBarKey) == nil {
                return true // Default to true
            }
            return bool(forKey: Self.showInStatusBarKey)
        }
        set {
            set(newValue, forKey: Self.showInStatusBarKey)
        }
    }

    var showInDock: Bool {
        get { // swiftlint:disable:this implicit_getter
            if object(forKey: Self.showInDockKey) == nil {
                return true // Default to true
            }
            return bool(forKey: Self.showInDockKey)
        }
        set {
            set(newValue, forKey: Self.showInDockKey)
        }
    }

    var launchAtLogin: Bool {
        get { // swiftlint:disable:this implicit_getter
            return bool(forKey: Self.launchAtLoginKey)
        }
        set {
            set(newValue, forKey: Self.launchAtLoginKey)
        }
    }

    var assistPathUpgradingWithPathMonitor: Bool {
        get { // swiftlint:disable:this implicit_getter
            return bool(forKey: Self.assistPathUpgradingWithPathMonitorKey)
        }
        set {
            set(newValue, forKey: Self.assistPathUpgradingWithPathMonitorKey)
        }
    }
}
