//
//  LaunchAtLoginHelper.swift
//  EduVPN
//

#if os(macOS)
import Cocoa
import ServiceManagement
import os.log

class LaunchAtLoginHelper {
    static var loginItemHelperBundleId: String {
        let appId = Bundle.main.bundleIdentifier! // swiftlint:disable:this force_unwrapping
        return "\(appId).LoginItemHelper"
    }

    static func setLaunchAtLoginEnabled(_ isEnabled: Bool) {
        let isSucceeded = SMLoginItemSetEnabled(loginItemHelperBundleId as CFString, isEnabled)
        if !isSucceeded {
            os_log("SMLoginItemSetEnabled failed. Could not set login item.",
                   log: Log.general, type: .debug)
        }
    }

    static func isOpenedOrReopenedByLoginItemHelper() -> Bool {
        guard let appleEvent = NSAppleEventManager.shared().currentAppleEvent,
            appleEvent.eventClass == kCoreEventClass,
            (appleEvent.eventID == kAEOpenApplication || appleEvent.eventID == kAEReopenApplication) else {
                return false
        }
        guard let propData = appleEvent.paramDescriptor(forKeyword: keyAEPropData) else { return false }
        return propData.stringValue == loginItemHelperBundleId
    }
}

#endif
