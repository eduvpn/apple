//
//  StatusItemController.swift
//  EduVPN
//

#if os(macOS)
import AppKit
import NetworkExtension

class StatusItemController {
    private var statusItem: NSStatusItem?

    private var shouldShowStatusItem = false {
        didSet { updateStatusItem() }
    }

    private var connectionStatus: NEVPNStatus? {
        didSet { updateStatusItem() }
    }

    // swiftlint:disable:next force_unwrapping
    private let statusBarImageWhenNotConnected = NSImage(named: "StatusItemNotConnected")!
    // swiftlint:disable:next force_unwrapping
    private let statusBarImageWhenConnecting = NSImage(named: "StatusItemConnecting")!
    // swiftlint:disable:next force_unwrapping
    private let statusBarImageWhenConnected = NSImage(named: "StatusItemConnected")!

    private var statusObservationToken: AnyObject?

    init() {
        startObservingTunnelStatus()
    }

    func setShouldShowStatusItem(_ shouldShow: Bool) {
        shouldShowStatusItem = shouldShow
    }
}

private extension StatusItemController {
    func updateStatusItem() {
        if (shouldShowStatusItem && self.statusItem == nil), let connectionStatus = connectionStatus {
            let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            statusItem.menu = createStatusMenu()
            self.statusItem = statusItem
            self.updateStatusItemImage(with: connectionStatus)
        } else if !shouldShowStatusItem {
            if let statusItem = self.statusItem {
                NSStatusBar.system.removeStatusItem(statusItem)
            }
            self.statusItem = nil
        }
    }

    func createStatusMenu() -> NSMenu {
        let appName = Config.shared.appName
        let menu = NSMenu()

        let showWindowMenuItem = NSMenuItem(title: NSLocalizedString("Show \(appName) window", comment: ""),
                                  action: #selector(AppDelegate.showMainWindow(_:)),
                                  keyEquivalent: "")
        showWindowMenuItem.target = NSApp.delegate
        menu.addItem(showWindowMenuItem)

        menu.addItem(NSMenuItem.separator())

        let preferencesMenuItem = NSMenuItem(title: NSLocalizedString("Preferences...", comment: ""),
                                             action: #selector(AppDelegate.showPreferences(_:)),
                                             keyEquivalent: "")
        preferencesMenuItem.target = NSApp.delegate
        menu.addItem(preferencesMenuItem)

        let helpMenuItem = NSMenuItem(title: NSLocalizedString("Help", comment: ""),
                                             action: #selector(StatusItemController.helpMenuItemClicked),
                                             keyEquivalent: "")
        helpMenuItem.target = self
        menu.addItem(helpMenuItem)

        let aboutMenuItem = NSMenuItem(title: NSLocalizedString("About", comment: ""),
                                             action: #selector(StatusItemController.aboutMenuItemClicked),
                                             keyEquivalent: "")
        aboutMenuItem.target = self
        menu.addItem(aboutMenuItem)

        menu.addItem(NSMenuItem.separator())

        let quitMenuItem = NSMenuItem(title: NSLocalizedString("Quit \(appName)", comment: ""),
                                             action: #selector(StatusItemController.quitMenuItemClicked),
                                             keyEquivalent: "")
        quitMenuItem.target = self
        menu.addItem(quitMenuItem)

        return menu
    }

    func updateStatusItemImage(with status: NEVPNStatus) {
        guard let statusItem = statusItem else { return }
        switch status {
        case .invalid, .disconnected:
            statusItem.button?.image = statusBarImageWhenNotConnected
        case .connecting, .disconnecting, .reasserting:
            statusItem.button?.image = statusBarImageWhenConnecting
        case .connected:
            statusItem.button?.image = statusBarImageWhenConnected
        @unknown default:
            statusItem.button?.image = statusBarImageWhenNotConnected
        }
    }

    func startObservingTunnelStatus() {
        statusObservationToken = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange, object: nil,
            queue: OperationQueue.main) { [weak self] notification in
                guard let self = self else { return }
                guard let session = notification.object as? NETunnelProviderSession else { return }
                self.connectionStatus = session.status
                self.updateStatusItemImage(with: session.status)
        }
    }
}

private extension StatusItemController {
    @objc func helpMenuItemClicked() {
        guard let url = Config.shared.supportURL else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    @objc func aboutMenuItemClicked() {
    }

    @objc func quitMenuItemClicked() {
    }
}

#endif
