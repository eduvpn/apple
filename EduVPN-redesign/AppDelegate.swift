//
//  AppDelegate.swift
//  eduVPN 2
//
//  Created by Johan Kool on 28/05/2020.
//  Copyright © 2020 SURFNet. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, ApplicationDelegate {

    var coordinator: AppCoordinator?
    
    #if os(iOS)
    
    let window: UIWindow
    
    #elseif os(macOS)
    
    let windowController: NSWindowController = {
        return NSStoryboard(name: "Main", bundle: nil).instantiateController(withIdentifier: "WindowController") as! NSWindowController //swiftlint:disable:this force_cast
    }()
    
    var window: NSWindow {
        return windowController.window! //swiftlint:disable:this force_cast
    }
    
    #endif
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Setup environment, here you can inject alternative services for testing
        let environment = Environment(mainService: MainService(), searchService: SearchService(), settingsService: SettingsService(), connectionService: ConnectionService())
        let appCoordinator = AppCoordinator(window: window, environment: environment)
        coordinator = appCoordinator
        appCoordinator.start()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

}

