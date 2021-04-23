//
//  UserDefaults+Preferences.swift
//  EduVPN
//

import Foundation

extension UserDefaults {

    private static let forceTCPDefaultsKey = "force_tcp"
    private static let shouldNotifyBeforeSessionExpiryKey = "shouldNotifyBeforeSessionExpiry"
    // swiftlint:disable:next identifier_name
    private static let hasAskedUserOnNotifyBeforeSessionExpiryKey = "hasAskedUserOnNotifyBeforeSessionExpiry"
    #if os(macOS)
    private static let showInStatusBarKey = "showInStatusBar"
    private static let isStatusItemInColorKey = "isStatusItemInColor"
    private static let showInDockKey = "showInDock"
    private static let launchAtLoginKey = "launchAtLogin"
    #endif

    var forceTCP: Bool {
        get {
            return bool(forKey: Self.forceTCPDefaultsKey)
        }
        set {
            set(newValue, forKey: Self.forceTCPDefaultsKey)
        }
    }

    var shouldNotifyBeforeSessionExpiry: Bool {
        get {
            return bool(forKey: Self.shouldNotifyBeforeSessionExpiryKey)
        }
        set {
            set(newValue, forKey: Self.shouldNotifyBeforeSessionExpiryKey)
        }
    }

    var hasAskedUserOnNotifyBeforeSessionExpiry: Bool {
        get {
            return bool(forKey: Self.hasAskedUserOnNotifyBeforeSessionExpiryKey)
        }
        set {
            set(newValue, forKey: Self.hasAskedUserOnNotifyBeforeSessionExpiryKey)
        }
    }

    #if os(macOS)
    var showInStatusBar: Bool {
        get {
            if object(forKey: Self.showInStatusBarKey) == nil {
                return true // Default to true
            }
            return bool(forKey: Self.showInStatusBarKey)
        }
        set {
            set(newValue, forKey: Self.showInStatusBarKey)
        }
    }

    var isStatusItemInColor: Bool {
        get {
            return bool(forKey: Self.isStatusItemInColorKey)
        }
        set {
            set(newValue, forKey: Self.isStatusItemInColorKey)
        }
    }

    var showInDock: Bool {
        get {
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
        get {
            return bool(forKey: Self.launchAtLoginKey)
        }
        set {
            set(newValue, forKey: Self.launchAtLoginKey)
        }
    }
    #endif
}
