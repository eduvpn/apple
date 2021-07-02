//
//  AppDelegate.swift
//  eduVPN 2
//
//  Created by Johan Kool on 28/05/2020.
//

import PromiseKit

#if os(iOS)
import UIKit

@UIApplicationMain
class AppDelegate: NSObject, UIApplicationDelegate {

    var environment: Environment?

    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        if let navigationController = window?.rootViewController as? NavigationController {
            environment = Environment(navigationController: navigationController)
            navigationController.environment = environment
            if let mainController = navigationController.children.first as? MainViewController {
                mainController.environment = environment
            }
        }
        return true
    }
    
}

#elseif os(macOS)
import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var mainWindow: NSWindow?
    var environment: Environment?
    var statusItemController: StatusItemController?
    var mainViewController: MainViewController?

    func applicationWillFinishLaunching(_ notification: Notification) {
        if UserDefaults.standard.showInDock {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let window = NSApp.windows[0]
        if let navigationController = window.rootViewController as? NavigationController {
            environment = Environment(navigationController: navigationController)
            navigationController.environment = environment
            if let mainController = navigationController.children.first as? MainViewController {
                mainController.environment = environment
                self.mainViewController = mainController
            }
        }

        Self.replaceAppNameInMenuItems(in: NSApp.mainMenu)

        let statusItemController = StatusItemController()
        statusItemController.dataSource = self.mainViewController
        statusItemController.delegate = self.mainViewController
        statusItemController.environment = environment
        self.mainViewController?.delegate = statusItemController
        self.statusItemController = statusItemController

        UserDefaults.standard.registerAppDefaults()

        setShowInStatusBarEnabled(
            UserDefaults.standard.showInStatusBar,
            shouldUseColorIcons: UserDefaults.standard.isStatusItemInColor)
        setShowInDockEnabled(UserDefaults.standard.showInDock)

        if LaunchAtLoginHelper.isOpenedOrReopenedByLoginItemHelper() &&
            UserDefaults.standard.showInStatusBar {
            // If we're showing a status item and the app was launched because
            //  the user logged in, don't show the window
            window.close()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }

        self.mainWindow = window
    }

    private static func replaceAppNameInMenuItems(in menu: NSMenu?) {
        for menuItem in menu?.items ?? [] {
            menuItem.title = menuItem.title.replacingOccurrences(
                of: "APP_NAME", with: Config.shared.appName)
            for subMenuItem in menuItem.submenu?.items ?? [] {
                subMenuItem.title = subMenuItem.title.replacingOccurrences(
                    of: "APP_NAME", with: Config.shared.appName)
            }
        }
    }

    private func isQuittingForLogoutShutdownOrRestart() -> Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent else {
            return false
        }
        guard let reasonCode = event.attributeDescriptor(forKeyword: kAEQuitReason) else {
            return false
        }
        switch reasonCode.enumCodeValue {
        case kAELogOut, kAEReallyLogOut,
             kAEShowShutdownDialog, kAEShutDown,
             kAEShowRestartDialog, kAERestart:
            return true
        default:
            return false
        }
    }

    private func showAlertConfirmingStopVPNAndQuit(
        connectionService: ConnectionServiceProtocol) -> NSApplication.TerminateReply {

        let alert = NSAlert()
        alert.alertStyle = .warning

        alert.messageText = NSLocalizedString(
            "Are you sure you want to quit \(Config.shared.appName)?",
            comment: "macOS alert title on attempt to quit app")
        alert.informativeText = NSLocalizedString(
            "The active VPN connection will be stopped when you quit.",
            comment: "macOS alert text on attempt to quit app")
        alert.addButton(withTitle: NSLocalizedString(
                            "Stop VPN & Quit",
                            comment: "macOS alert button on attempt to quit app"))
        alert.addButton(withTitle: NSLocalizedString(
                            "Cancel", comment: "button title"))

        func handleQuitConfirmationResult(_ result: NSApplication.ModalResponse) {
            if case .alertFirstButtonReturn = result {
                firstly {
                    connectionService.disableVPN()
                }.map { _ in
                    NSApp.reply(toApplicationShouldTerminate: true)
                }.cauterize()
            } else {
                NSApp.reply(toApplicationShouldTerminate: false)
            }
        }

        if let window = NSApp.windows.first {
            alert.beginSheetModal(for: window) { result in
                handleQuitConfirmationResult(result)
            }
        } else {
            let result = alert.runModal()
            handleQuitConfirmationResult(result)
        }

        return .terminateLater
    }

    private func showAlertConfirmingLogoutWithVPNOn(
        connectionService: ConnectionServiceProtocol) -> NSApplication.TerminateReply {

        let alert = NSAlert()
        alert.alertStyle = .warning

        alert.messageText = NSLocalizedString(
            "You are logging out while the VPN is on",
            comment: "macOS alert title on attempt to quit app by logout")
        alert.informativeText = NSLocalizedString(
            "The VPN will be on when a user logs in next. You can turn off the VPN then by opening the \(Config.shared.appName) app.",
            comment: "macOS alert text on attempt to quit app by logout")
        alert.addButton(withTitle: NSLocalizedString(
                            "Quit",
                            comment: "macOS alert button on attempt to quit app by logout"))
        alert.addButton(withTitle: NSLocalizedString(
                            "Stop VPN & Quit",
                            comment: "macOS alert button on attempt to quit app by logout"))

        func handleQuitConfirmationResult(_ result: NSApplication.ModalResponse) {
            if case .alertFirstButtonReturn = result {
                NSApp.reply(toApplicationShouldTerminate: true)
            } else {
                firstly {
                    connectionService.disableVPN()
                }.map { _ in
                    NSApp.reply(toApplicationShouldTerminate: true)
                }.cauterize()
            }
        }

        if let window = NSApp.windows.first {
            alert.beginSheetModal(for: window) { result in
                handleQuitConfirmationResult(result)
            }
        } else {
            let result = alert.runModal()
            handleQuitConfirmationResult(result)
        }
        return .terminateLater
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let connectionService = environment?.connectionService else {
            return .terminateNow
        }

        guard connectionService.isVPNEnabled else {
            return .terminateNow
        }

        if isQuittingForLogoutShutdownOrRestart() {
            return showAlertConfirmingLogoutWithVPNOn(connectionService: connectionService)
        } else {
            return showAlertConfirmingStopVPNAndQuit(connectionService: connectionService)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return !UserDefaults.standard.showInStatusBar
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if LaunchAtLoginHelper.isOpenedOrReopenedByLoginItemHelper() {
            return false
        }
        showMainWindow(self)
        setShowInDockEnabled(UserDefaults.standard.showInDock)
        return true
    }
}

extension AppDelegate {
    @objc func showMainWindow(_ sender: Any?) {
        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func showPreferences(_ sender: Any) {
        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        environment?.navigationController?.presentPreferences()
    }

    @IBAction func showAboutPanel(_ sender: Any?) {
        NSApp.orderFrontStandardAboutPanel(options: [
            .credits: sourceRepositoryLinkMessage
        ])
    }

    @objc func newDocument(_ sender: Any) {
        guard let navigationController = environment?.navigationController else {
            return
        }
        if navigationController.isToolbarLeftButtonShowsAddServerUI {
            navigationController.toolbarLeftButtonClicked(self)
        }
    }

    @IBAction func importOpenVPNConfig(_ sender: Any) {
        guard let mainWindow = mainWindow else { return }
        guard let persistenceService = environment?.persistenceService else { return }
        guard let environment = self.environment else { return }

        mainWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        let openPanel = NSOpenPanel()
        openPanel.prompt = NSLocalizedString(
            "Import",
            comment: "macOS import ovpn file open panel button title")
        openPanel.allowedFileTypes = ["ovpn"]
        openPanel.allowsMultipleSelection = false
        openPanel.beginSheetModal(for: mainWindow) { response in
            guard response == .OK else { return }
            guard let url = openPanel.urls.first else { return }
            var importError: Error?
            do {
                let result = try OpenVPNConfigImportHelper.copyConfig(from: url)
                if result.hasAuthUserPass {
                    let credentialsVC = environment.instantiateCredentialsViewController(
                        initialCredentials: OpenVPNConfigCredentials.emptyCredentials)
                    credentialsVC.onCredentialsSaved = { credentials in
                        let dataStore = PersistenceService.DataStore(
                            path: result.configInstance.localStoragePath)
                        dataStore.openVPNConfigCredentials = credentials
                        persistenceService.addOpenVPNConfiguration(result.configInstance)
                        self.mainViewController?.refresh()
                    }
                    mainWindow.rootViewController?.presentAsSheet(credentialsVC)
                } else {
                    persistenceService.addOpenVPNConfiguration(result.configInstance)
                }
            } catch {
                importError = error
            }

            self.mainViewController?.refresh()

            if let importError = importError {
                if let navigationController = self.environment?.navigationController {
                    navigationController.showAlert(for: importError)
                }
            }
        }
    }

    func setShowInStatusBarEnabled(_ isEnabled: Bool, shouldUseColorIcons: Bool) {
        statusItemController?.setShouldShowStatusItem(isEnabled, shouldUseColorIcons: shouldUseColorIcons)
    }

    func setShowInDockEnabled(_ isEnabled: Bool) {
        if isEnabled {
            if NSApp.activationPolicy() != .regular {
                NSApp.setActivationPolicy(.regular)
            }
        } else {
            if NSApp.activationPolicy() != .accessory {
                NSApp.setActivationPolicy(.accessory)
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
                    NSApp.unhide(nil)
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        }
    }

    func setLaunchAtLoginEnabled(_ isEnabled: Bool) {
        LaunchAtLoginHelper.setLaunchAtLoginEnabled(isEnabled)
    }
}

extension AppDelegate: NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.keyEquivalent == "n" {
            return environment?.navigationController?.isToolbarLeftButtonShowsAddServerUI ?? false
        }
        return true
    }
}

extension AppDelegate {
    var sourceRepositoryLink: String { "https://github.com/eduvpn/apple" }
    var sourceRepositoryLinkMessage: NSAttributedString {
        let url = URL(string: sourceRepositoryLink)! // swiftlint:disable:this force_unwrapping
        let font = NSFont.systemFont(ofSize: 10, weight: .light)
        let string = NSMutableAttributedString(
            string: NSLocalizedString(
                "For source code and licenses, please see: ",
                comment: "macOS about panel message"),
            attributes: [.font: font])
        let linkedString = NSAttributedString(
            string: sourceRepositoryLink,
            attributes: [.link: url, .font: font])
        string.append(linkedString)
        return string
    }
}

#endif
