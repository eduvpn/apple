//
//  PreferencesService.swift
//  eduVPN
//
//  Created by Johan Kool on 10/08/2017.
//  Copyright © 2017-2019 Commons Conservancy.
//

import Cocoa
import ServiceManagement

class PreferencesService: NSObject {
    
    override init() {
        launchAtLogin = PreferencesService.launchAtLogin(bundle: PreferencesService.loginHelperBundle)
        UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
        super.init()
        UserDefaults.standard.addObserver(self, forKeyPath: "launchAtLogin", options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: "showInDock", options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: "showInStatusBar", options: .new, context: nil)
    }
    
    var launchAtLogin: Bool {
        didSet {
            setLaunchAtLogin(bundle: PreferencesService.loginHelperBundle, enabled: launchAtLogin)
        }
    }
    
    var developerMode: Bool {
        get {
            return  UserDefaults.standard.bool(forKey: "developerMode")
        }
        set {
            UserDefaults.standard.set(developerMode, forKey: "developerMode")
        }
    }
    
    private static var loginHelperBundle: Bundle {
        let mainBundle = Bundle.main
        let bundlePath = (mainBundle.bundlePath as NSString).appendingPathComponent("Contents/Library/LoginItems/LoginItemHelper.app")
        return Bundle(path: bundlePath)!
    }
    
    private static func launchAtLogin(bundle: Bundle) -> Bool {
        // From the docs regarding deprecation:
        // For the specific use of testing the state of a login item that may have been
        // enabled with SMLoginItemSetEnabled() in order to show that state to the
        // user, this function remains the recommended API. A replacement API for this
        // specific use will be provided before this function is removed.
        guard let dictionaries = SMCopyAllJobDictionaries(kSMDomainUserLaunchd).takeRetainedValue() as? [[String: Any]] else {
            return false
        }
        return dictionaries.first(where: { $0["Label"] as? String == bundle.bundleIdentifier }) != nil
    }
    
    private func setLaunchAtLogin(bundle: Bundle, enabled: Bool) {
        let status = LSRegisterURL(bundle.bundleURL as CFURL, true)
        if status != noErr {
            NSLog("LSRegisterURL failed to register \(bundle.bundleURL) [\(status)]")
        }
        
        if !SMLoginItemSetEnabled(bundle.bundleIdentifier! as CFString, enabled) {
            NSLog("SMLoginItemSetEnabled failed!")
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
         updateForUIPreferences()
    }

    func updateForUIPreferences() {
        let launchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")
        var showInDock = UserDefaults.standard.bool(forKey: "showInDock")
        let showInStatusBar = UserDefaults.standard.bool(forKey: "showInStatusBar")
        
        self.launchAtLogin = launchAtLogin
        
        // We should always be visible somewhere
        if !showInDock && !showInStatusBar {
            showInDock = true
            UserDefaults.standard.set(true, forKey: "showInDock")
        }
        
        if showInDock {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
        
        (NSApp.delegate as! AppDelegate).statusItemIsVisible = showInStatusBar
    }
    
}
