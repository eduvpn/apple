//
//  AppDelegate.swift
//  eduVPN
//
//  Created by Johan Kool on 28/06/2017.
//  Copyright © 2017-2019 Commons Conservancy.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    var appCoordinator: AppCoordinator!
    var statusItem: NSStatusItem?
    @IBOutlet var statusMenu: NSMenu!

    func applicationWillFinishLaunching(_ notification: Notification) {
        // <UNCOMMENT>
//        ServiceContainer.preferencesService.updateForUIPreferences()
        // </UNCOMMENT>

        // Disabled until best approach to get token is determined
        //        // Setup incoming URL handling
        //        NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(AppDelegate.handleAppleEvent(event:with:)), forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        UserDefaults.standard.register(defaults: NSDictionary(contentsOf: Bundle.main.url(forResource: "Defaults", withExtension: "plist")!)! as! [String : Any])

        if #available(OSX 10.12, *) {
            createStatusItem()
        }

        // <UNCOMMENT>
//        NotificationCenter.default.addObserver(self,
//                                               selector: #selector(connectionStateChanged(notification:)),
//                                               name: ConnectionService.stateChanged,
//                                               object: ServiceContainer.connectionService)
        // </UNCOMMENT>

        ValueTransformer.setValueTransformer(DurationTransformer(),
                                             forName: NSValueTransformerName(rawValue: "DurationTransformer"))

        appCoordinator = AppCoordinator()
        appCoordinator.start()

        // Adjust app name in menu and window
        let appName = Config.shared.appName
        if appName != "eduVPN" {
            let fix: (NSMenuItem) -> Void = { menuItem in
                menuItem.title = menuItem.title.replacingOccurrences(of: "eduVPN", with: appName)
            }
            
            NSApp.mainMenu?.items.forEach { menuItem in
                menuItem.submenu?.items.forEach {
                    fix($0)
                }
            }
            
            statusMenu.items.forEach(fix)
            appCoordinator.fixAppName(to: appName)
        }
    }

    // <UNCOMMENT>
//    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
//        switch ServiceContainer.connectionService.state {
//        case .disconnected:
//            return .terminateNow
//        case .connecting, .disconnecting:
//            return .terminateCancel
//        case .connected:
//            ServiceContainer.connectionService.disconnect { result in
//                DispatchQueue.main.async {
//                    switch result {
//                    case .success:
//                        NSApp.reply(toApplicationShouldTerminate: true)
//                    case .failure(let error):
//                        if let alert = NSAlert(customizedError: error) {
//                            NSApp.reply(toApplicationShouldTerminate: false)
//                            if let window = self.mainWindowController.window {
//                                alert.beginSheetModal(for: window)
//                            } else {
//                                alert.runModal()
//                            }
//                        } else {
//                            NSApp.reply(toApplicationShouldTerminate: true)
//                        }
//                    }
//                }
//            }
//            return .terminateLater
//        }
//    }
    // </UNCOMMENT>

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func handleAppleEvent(event: NSAppleEventDescriptor, with: NSAppleEventDescriptor) {
        // Disabled until best approach to get token is determined
        //        if event.eventClass == AEEventClass(kInternetEventClass),
        //            event.eventID == AEEventID(kAEGetURL),
        //            let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue {
        //            ServiceContainer.connectionService.parseCallback(urlString: urlString)
        //        }
    }

    @IBAction func showWindow(_ sender: Any) {
        guard let window = appCoordinator.window else {
            return
        }
        
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private lazy var preferencesWindowController = NSStoryboard(name: "Main", bundle: nil).instantiateController(withIdentifier: "PreferencesController") as! NSWindowController

    @objc @IBAction func showPreferences(_ sender: Any) {
        guard let window = appCoordinator.window, let preferencesWindow = preferencesWindowController.window else {
            return
        }

        window.beginSheet(preferencesWindow, completionHandler: nil)

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    @objc @IBAction func closePreferences(_ sender: Any) {
        guard let window = appCoordinator.window, let preferencesWindow = preferencesWindowController.window else {
            return
        }

        window.endSheet(preferencesWindow)
    }

    private func createStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: 26)
        statusItem?.menu = statusMenu
        updateStatusItemImage()
    }

    private func updateStatusItemImage() {
        // <UNCOMMENT>
//        switch ServiceContainer.connectionService.state {
//        case .connecting, .disconnecting:
//            statusItem?.image = #imageLiteral(resourceName: "Status-connecting")
//            NSApp.applicationIconImage = #imageLiteral(resourceName: "Icon-connecting")
//        case .connected:
//            statusItem?.image = #imageLiteral(resourceName: "Status-connected")
//            NSApp.applicationIconImage = #imageLiteral(resourceName: "Icon-connected")
//        case .disconnected:
//            statusItem?.image = #imageLiteral(resourceName: "Status-disconnected")
//            NSApp.applicationIconImage = #imageLiteral(resourceName: "Icon-disconnected")
//        }
        // </UNCOMMENT>
    }

    var statusItemIsVisible: Bool = false {
        didSet {
            if #available(OSX 10.12, *) {
                statusItem?.isVisible = statusItemIsVisible
            } else {
                // Fallback on earlier versions
                if oldValue != statusItemIsVisible {
                    if statusItemIsVisible {
                        createStatusItem()
                    } else {
                        if let statusItem = statusItem {
                            NSStatusBar.system.removeStatusItem(statusItem)
                        }
                    }
                }
            }
        }
    }

    @objc private func connectionStateChanged(notification: NSNotification) {
        DispatchQueue.main.async {
            self.updateStatusItemImage()
        }
    }
}
