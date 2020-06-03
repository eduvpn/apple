//
//  AppDelegate.swift
//  eduVPN 2
//
//  Created by Johan Kool on 28/05/2020.
//  Copyright © 2020 SURFNet. All rights reserved.
//

#if os(iOS)
import UIKit

@UIApplicationMain
class AppDelegate: NSObject, ApplicationDelegate {

    var coordinator: AppCoordinator?
    
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
    
    var coordinator: AppCoordinator?
    
    let windowController: NSWindowController = {
        return NSStoryboard(name: "Main", bundle: nil).instantiateController(withIdentifier: "WindowController") as! NSWindowController //swiftlint:disable:this force_cast
    }()
    
    var window: NSWindow {
        return windowController.window! //swiftlint:disable:this force_cast
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setup(window: window)
    }
    
}

#endif

extension AppDelegate {
    
    private func setup(window: Window) {
        // Setup environment, here you can inject alternative services for testing
        let config = Config.shared
        let environment = Environment(config: config, mainService: MainService(), searchService: SearchService(config: config), settingsService: SettingsService(), connectionService: ConnectionService())
        let appCoordinator = AppCoordinator(window: window, environment: environment)
        coordinator = appCoordinator
        appCoordinator.start()
    }
    
}
