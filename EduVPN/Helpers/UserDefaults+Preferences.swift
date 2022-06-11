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
    private static let isPrivacyDisclaimerAcceptedKey = "isPrivacyDisclaimerAccepted"
    #if os(macOS)
    private static let showInStatusBarKey = "showInStatusBar"
    private static let isStatusItemInColorKey = "isStatusItemInColor"
    private static let showInDockKey = "showInDock"
    private static let launchAtLoginKey = "launchAtLogin"
    #endif

    func clearPreferences() {
        var keys = [
            Self.forceTCPDefaultsKey,
            Self.shouldNotifyBeforeSessionExpiryKey,
            Self.hasAskedUserOnNotifyBeforeSessionExpiryKey
        ]
        #if os(macOS)
        keys.append(contentsOf: [
            Self.showInStatusBarKey,
            Self.isStatusItemInColorKey,
            Self.showInDockKey,
            Self.launchAtLoginKey
        ])
        #endif
        for key in keys {
            removeObject(forKey: key)
        }
    }

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

    var isPrivacyDisclaimerAccepted: Bool {
        get {
            return bool(forKey: Self.isPrivacyDisclaimerAcceptedKey)
        }
        set {
            set(newValue, forKey: Self.isPrivacyDisclaimerAcceptedKey)
        }
    }

    #if os(macOS)
    var showInStatusBar: Bool {
        get {
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

    func registerAppDefaults() {
        register(defaults: [
                    Self.showInStatusBarKey: true,
                    Self.showInDockKey: true
        ])
    }
    #endif
}
