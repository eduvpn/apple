//
//  AppDelegate.swift
//  eduVPN
//
//  Created by Johan Kool on 28/06/2017.
//  Copyright © 2017-2019 Commons Conservancy.
//

import Cocoa
import PromiseKit

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    var appCoordinator: AppCoordinator!
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Disabled until best approach to get token is determined
        //        // Setup incoming URL handling
        //        NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(AppDelegate.handleAppleEvent(event:with:)), forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        UserDefaults.standard.register(defaults: NSDictionary(contentsOf: Bundle.main.url(forResource: "Defaults", withExtension: "plist")!)! as! [String: Any]) //swiftlint:disable:this force_cast
        PreferencesService.shared.updateForUIPreferences()
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(connectionStateChanged(notification:)),
                                               name: .NEVPNStatusDidChange,
                                               object: nil)
  
        ValueTransformer.setValueTransformer(DurationTransformer(),
                                             forName: NSValueTransformerName(rawValue: "DurationTransformer"))
        
        appCoordinator = AppCoordinator()
        appCoordinator.start()

        // Adjust app name in menu and window
        let appName = Config.shared.appName ?? "eduVPN"
        if appName != "eduVPN" {
            let fix: (NSMenuItem) -> Void = { menuItem in
                menuItem.title = menuItem.title.replacingOccurrences(of: "eduVPN", with: appName)
            }
            
            NSApp.mainMenu?.items.forEach { menuItem in
                menuItem.submenu?.items.forEach {
                    fix($0)
                }
            }
            
            appCoordinator.fixAppName(to: appName)
        }
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let status = appCoordinator.tunnelProviderManagerCoordinator.currentManager?.connection.status else {
            return .terminateNow
        }
        
        switch status {
        case .disconnected, .invalid:
            return .terminateNow
        case .connecting, .disconnecting, .reasserting:
            return .terminateCancel
        case .connected:
            func disconnect() {
                appCoordinator.tunnelProviderManagerCoordinator
                    .disconnect()
                    .then { _ -> Promise<Void> in
                        NSApp.reply(toApplicationShouldTerminate: true)
                        return Promise.value(())
                    }
                    .recover { error in
                        if let alert = NSAlert(customizedError: error) {
                            NSApp.reply(toApplicationShouldTerminate: false)
                            if let window = self.appCoordinator.mainWindowController.window {
                                alert.beginSheetModal(for: window)
                            } else {
                                alert.runModal()
                            }
                        } else {
                            NSApp.reply(toApplicationShouldTerminate: true)
                        }
                    }
            }
            
            func handleResult(_ result: NSApplication.ModalResponse) {
                switch result {
                case .alertFirstButtonReturn:
                    disconnect()
                default:
                    NSApp.reply(toApplicationShouldTerminate: false)
                }
            }
            
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = NSLocalizedString("Are you sure you want to quit \(Config.shared.appName)?", comment: "")
            alert.informativeText = NSLocalizedString("Your VPN connection will be disconnected when you quit.", comment: "")
            alert.addButton(withTitle: NSLocalizedString("Disconnect & Quit", comment: ""))
            alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
            
            if let window = self.appCoordinator.mainWindowController.window {
                alert.beginSheetModal(for: window) { result in
                    handleResult(result)
                }
            } else {
                let result = alert.runModal()
                handleResult(result)
            }
            
            return .terminateLater
        @unknown default:
            return .terminateCancel
        }
    }
    
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
    
    private lazy var preferencesWindowController = NSStoryboard(name: "Main", bundle: nil).instantiateController(withIdentifier: "PreferencesController") as! NSWindowController  //swiftlint:disable:this force_cast
    
    @IBAction func showPreferences(_ sender: Any) {
        guard let window = appCoordinator.window, let preferencesWindow = preferencesWindowController.window else {
            return
        }
        
        window.beginSheet(preferencesWindow, completionHandler: nil)
        
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
    
    @IBAction func closePreferences(_ sender: Any) {
        guard let window = appCoordinator.window, let preferencesWindow = preferencesWindowController.window else {
            return
        }
        
        window.endSheet(preferencesWindow)
    }

    @objc private func connectionStateChanged(notification: NSNotification) {
        DispatchQueue.main.async {
            guard let status = self.appCoordinator.tunnelProviderManagerCoordinator.currentManager?.connection.status else {
                NSApp.applicationIconImage = NSImage(named: "Icon-off")
                return
            }
            switch status {
            case .connecting, .disconnecting, .reasserting:
                NSApp.applicationIconImage = NSImage(named: "Icon-connecting")
            case .connected:
                NSApp.applicationIconImage = NSImage(named: "Icon-connected")
            case .disconnected:
                NSApp.applicationIconImage = NSImage(named: "Icon-off")
            case .invalid:
                NSApp.applicationIconImage = NSImage(named: "Icon-invalid")
            @unknown default:
                NSApp.applicationIconImage = NSImage(named: "Icon-off")
            }
        }
    }
    
    @IBAction func showSupportURL(_ sender: Any?) {
        guard let url = Config.shared.supportURL else {
            return
        }
        NSWorkspace.shared.open(url)
    }
    
}
