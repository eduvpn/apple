//
//  AppDelegate.swift
//  eduVPN 2
//
//  Created by Johan Kool on 28/05/2020.
//

#if os(iOS)
import UIKit

@UIApplicationMain
class AppDelegate: NSObject, ApplicationDelegate {
    
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        self.window = window
        setup(window: window)
        return true
    }
    
}

#elseif os(macOS)
import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, ApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let window = NSApp.windows[0]
        setup(window: window)
    }
    
}

#endif

extension AppDelegate {
    
    private func setup(window: Window) {
        // Setup environment, here you can inject alternative services for testing
        let config = Config.shared
        let environment = Environment(config: config, storyboard: Storyboard(name: "Main", bundle: nil), mainService: MainService(), searchService: SearchService(config: config), settingsService: SettingsService(), connectionService: ConnectionService())
    }
    
}
