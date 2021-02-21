//
//  StatusItemController.swift
//  EduVPN
//

#if os(macOS)
import AppKit
import NetworkExtension

protocol StatusItemControllerDataSource: class {
    func currentServer() -> (ConnectionViewModel.ConnectionFlowStatus, ConnectableInstance?)
    func addedServersListRows() -> [MainViewModel.Row]
}

protocol StatusItemControllerDelegate: class {
    func startConnectionFlow(with instance: ConnectableInstance)
    func disableVPN()
}

class StatusItemController {

    struct ConnectionFlowStatusEntries {
        private var flowStatusItem: NSMenuItem
        private var activeInstanceItem: NSMenuItem
        private var disableVPNItem: NSMenuItem
        private(set) var separatorItem: NSMenuItem

        var activeInstance: ConnectableInstance?
    }

    struct ConnectableInstanceEntry {
        var menuItem: NSMenuItem
        var row: MainViewModel.Row
    }

    struct ConnectableInstanceEntries {
        private var entries: [ConnectableInstanceEntry]
    }

    weak var dataSource: StatusItemControllerDataSource? {
        didSet {
            updateStatusMenuFromDataSource()
        }
    }
    weak var delegate: StatusItemControllerDelegate?

    private var statusItem: NSStatusItem?

    private var connectionFlowStatusEntries: ConnectionFlowStatusEntries
    private var connectableInstanceEntries: ConnectableInstanceEntries

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
        connectionFlowStatusEntries = ConnectionFlowStatusEntries()
        connectableInstanceEntries = ConnectableInstanceEntries()
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

        for item in connectionFlowStatusEntries.menuItems {
            menu.addItem(item)
        }
        for item in connectableInstanceEntries.menuItems {
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())

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

    func updateStatusMenuFromDataSource() {
        if let dataSource = dataSource {
            let (flowStatus, activeInstance) = dataSource.currentServer()
            let rows = dataSource.addedServersListRows()
            let activeRow: MainViewModel.Row? = {
                guard let activeInstance = activeInstance else { return nil }
                return rows.first(
                    where: {
                        $0.connectableInstance?.localStoragePath == activeInstance.localStoragePath
                    })
            }()
            self.connectableInstanceEntries.updateEntries(
                rows: rows, controller: self,
                after: connectionFlowStatusEntries.separatorItem,
                in: statusItem?.menu)
            self.connectableInstanceEntries.updateStatus(
                flowStatus: flowStatus, activeRow: activeRow)
            self.connectionFlowStatusEntries.updateStatus(
                flowStatus: flowStatus, activeRow: activeRow,
                controller: self)
        } else {
            self.connectableInstanceEntries.updateEntries(
                rows: [], controller: self,
                after: connectionFlowStatusEntries.separatorItem,
                in: statusItem?.menu)
            self.connectableInstanceEntries.updateStatus(
                flowStatus: .notConnected, activeRow: nil)
            self.connectionFlowStatusEntries.updateStatus(
                flowStatus: .notConnected, activeRow: nil,
                controller: self)
        }
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

extension StatusItemController.ConnectionFlowStatusEntries {
    init() {
        flowStatusItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        flowStatusItem.isHidden = true
        flowStatusItem.isEnabled = false

        activeInstanceItem = NSMenuItem(
            title: "",
            action: #selector(AppDelegate.showMainWindow(_:)),
            keyEquivalent: "")
        activeInstanceItem.target = NSApp.delegate
        activeInstanceItem.isHidden = true

        disableVPNItem = NSMenuItem(
            title: NSLocalizedString("Disable VPN", comment: ""),
            action: #selector(StatusItemController.disableVPNMenuItemClicked),
            keyEquivalent: "")
        disableVPNItem.isHidden = true
        disableVPNItem.isEnabled = false

        separatorItem = NSMenuItem.separator()
    }

    func updateStatus(flowStatus: ConnectionViewModel.ConnectionFlowStatus,
                      activeRow: MainViewModel.Row?,
                      controller: StatusItemController) {
        flowStatusItem.title = flowStatus.localizedText
        flowStatusItem.isHidden = false

        activeInstanceItem.title = activeRow?.displayText ?? ""
        activeInstanceItem.isHidden = (activeRow == nil || flowStatus == .notConnected)

        disableVPNItem.target = controller
        disableVPNItem.isHidden = (activeRow == nil || flowStatus == .notConnected)
        disableVPNItem.isEnabled = (flowStatus == .connected || flowStatus == .connecting || flowStatus == .reconnecting)
    }

    var menuItems: [NSMenuItem] {
        [flowStatusItem, activeInstanceItem, disableVPNItem, separatorItem]
    }
}

extension StatusItemController.ConnectableInstanceEntries {
    init() {
        self.entries = []
    }

    mutating func updateEntries(
        rows: [MainViewModel.Row], controller: StatusItemController,
        after markerMenuItem: NSMenuItem, in menu: NSMenu?) {
        let useIndentation = rows.first?.rowKind.isSectionHeader ?? false
        var updatedEntries: [StatusItemController.ConnectableInstanceEntry] = []
        for (index, row) in rows.enumerated() {
            let item = NSMenuItem(
                title: row.displayText,
                action: #selector(StatusItemController.connectableInstanceClicked(sender:)),
                keyEquivalent: "")
            item.target = row.rowKind.isServerRow ? controller : nil
            item.isEnabled = row.rowKind.isServerRow
            item.indentationLevel = (useIndentation && row.rowKind.isServerRow) ? 1 : 0
            item.tag = index
            let entry = StatusItemController.ConnectableInstanceEntry(menuItem: item, row: row)
            updatedEntries.append(entry)
        }

        if let menu = menu {
            let firstIndex = menu.index(of: markerMenuItem) + 1
            let lastIndex = firstIndex + entries.count
            if lastIndex < menu.numberOfItems {
                if let afterEntriesItem = menu.item(at: lastIndex),
                   afterEntriesItem.isSeparatorItem {
                    afterEntriesItem.isHidden = rows.isEmpty
                }
            }
            for index in (firstIndex ..< lastIndex).reversed() {
                menu.removeItem(at: index)
            }
            for entry in updatedEntries.reversed() {
                menu.insertItem(entry.menuItem, at: firstIndex)
            }
        }
        self.entries = updatedEntries
    }

    func updateStatus(flowStatus: ConnectionViewModel.ConnectionFlowStatus,
                      activeRow: MainViewModel.Row?) {
        let activeInstance = activeRow?.connectableInstance
        for entry in entries where entry.row.rowKind.isServerRow {
            if let activeInstance = activeInstance,
               let instance = entry.row.connectableInstance,
               flowStatus != .notConnected,
               instance.localStoragePath == activeInstance.localStoragePath {
                entry.menuItem.state = .on
            } else {
                entry.menuItem.state = .off
            }
        }
    }

    var menuItems: [NSMenuItem] {
        entries.map { $0.menuItem }
    }

    func row(for menuItem: NSMenuItem) -> MainViewModel.Row? {
        let tag = menuItem.tag
        guard tag >= 0 && tag < entries.count else { return nil }
        let entry = entries[tag]
        guard entry.menuItem == menuItem else { return nil }
        return entry.row
    }

    func row(for connectableInstance: ConnectableInstance) -> MainViewModel.Row? {
        entries.first(where: { entry in
            guard let entryConnectableInstance = entry.row.connectableInstance else {
                return false
            }
            return entryConnectableInstance.localStoragePath == connectableInstance.localStoragePath
        })?.row
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
        NSApp.orderFrontStandardAboutPanel(self)
    }

    @objc func quitMenuItemClicked() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.terminate(self)
    }

    @objc func disableVPNMenuItemClicked() {
        delegate?.disableVPN()
    }

    @objc func connectableInstanceClicked(sender: AnyObject) {
        if let item = sender as? NSMenuItem,
           let row = connectableInstanceEntries.row(for: item),
           let connectableInstance = row.connectableInstance {
            delegate?.startConnectionFlow(with: connectableInstance)
        }
    }
}

extension StatusItemController: MainViewControllerDelegate {
    func mainViewControllerAddedServersListChanged(_ viewController: MainViewController) {
        updateStatusMenuFromDataSource()
    }

    func mainViewController(
        _ viewController: MainViewController,
        didObserveConnectionFlowStatusChange flowStatus: ConnectionViewModel.ConnectionFlowStatus,
        in connectionViewController: ConnectionViewController) {

        let activeInstance = connectionViewController.connectableInstance
        let activeRow = connectableInstanceEntries.row(for: activeInstance)

        self.connectableInstanceEntries.updateStatus(
            flowStatus: flowStatus, activeRow: activeRow)
        self.connectionFlowStatusEntries.updateStatus(
            flowStatus: flowStatus, activeRow: activeRow,
            controller: self)
    }
}
#endif
