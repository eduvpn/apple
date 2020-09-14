//
//  LaunchAtLoginHelper.swift
//  EduVPN
//

#if os(macOS)
import Cocoa
import ServiceManagement
import os.log

class LaunchAtLoginHelper {
    static func setLaunchAtLoginEnabled(_ isEnabled: Bool) {
        let appId = Bundle.main.bundleIdentifier! // swiftlint:disable:this force_unwrapping
        let helperBundleId = "\(appId).LoginItemHelper"
        let isSucceeded = SMLoginItemSetEnabled(helperBundleId as CFString, isEnabled)
        if !isSucceeded {
            os_log("SMLoginItemSetEnabled failed. Could not set login item.",
                   log: Log.general, type: .debug)
        }
    }
}

#endif
