//
//  StatusItemController.swift
//  EduVPN
//

#if os(macOS)
import AppKit

protocol StatusItemControllerDataSource: AnyObject {
    func currentServer() -> (ConnectionViewModel.ConnectionFlowStatus, ConnectableInstance?)
    func addedServersListRows() -> [MainViewModel.Row]
}

protocol StatusItemControllerDelegate: AnyObject {
    func startConnectionFlow(with instance: ConnectableInstance)
    func disableVPN()
}

class StatusItemController: NSObject {

    struct ConnectionFlowStatusEntries {
        private var flowStatusItem: NSMenuItem
        private var activeInstanceItem: NSMenuItem
        private var connectionInfoItem: NSMenuItem
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
    var environment: Environment?

    private var statusItem: NSStatusItem?

    private var isMenuVisible: Bool = false {
        didSet { updateConnectionInfoState() }
    }
    private var flowStatus: ConnectionViewModel.ConnectionFlowStatus = .notConnected {
        didSet {
            updateConnectionInfoState()
            updateStatusItem()
        }
    }

    private var connectionFlowStatusEntries: ConnectionFlowStatusEntries
    private var connectableInstanceEntries: ConnectableInstanceEntries

    private var shouldShowStatusItem = false {
        didSet { updateStatusItem() }
    }

    private var shouldUseColorIcons = false {
        didSet { updateStatusItem() }
    }

    private var statusObservationToken: AnyObject?
    private var connectionInfoHelper: StatusItemConnectionInfoHelper?

    override init() {
        connectionFlowStatusEntries = ConnectionFlowStatusEntries()
        connectableInstanceEntries = ConnectableInstanceEntries()
        super.init()
    }

    func setShouldShowStatusItem(_ shouldShow: Bool, shouldUseColorIcons: Bool) {
        self.shouldShowStatusItem = shouldShow
        self.shouldUseColorIcons = shouldUseColorIcons
    }
}

private extension StatusItemController {
    func updateStatusItem() {
        if shouldShowStatusItem && self.statusItem == nil {
            let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            statusItem.menu = createStatusMenu()
            self.statusItem = statusItem
        } else if !shouldShowStatusItem {
            if let statusItem = self.statusItem {
                NSStatusBar.system.removeStatusItem(statusItem)
            }
            self.statusItem = nil
        }
        self.updateStatusItemImage()
    }

    func createStatusMenu() -> NSMenu {
        let appName = Config.shared.appName
        let menu = NSMenu()
        menu.delegate = self

        for item in connectionFlowStatusEntries.menuItems {
            menu.addItem(item)
        }
        for item in connectableInstanceEntries.menuItems {
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())

        let showWindowMenuItem = NSMenuItem(
            title: String(format: NSLocalizedString(
                              "Show %@ window",
                              comment: "macOS App menu item"),
                          appName),
            action: #selector(AppDelegate.showMainWindow(_:)),
            keyEquivalent: "")
        showWindowMenuItem.target = NSApp.delegate
        menu.addItem(showWindowMenuItem)

        menu.addItem(NSMenuItem.separator())

        let preferencesMenuItem = NSMenuItem(
            title: NSLocalizedString("Preferences...", comment: "macOS App menu item"),
            action: #selector(AppDelegate.showPreferences(_:)),
            keyEquivalent: "")
        preferencesMenuItem.target = NSApp.delegate
        menu.addItem(preferencesMenuItem)

        let helpMenuItem = NSMenuItem(
            title: NSLocalizedString("Help", comment: "macOS App menu item"),
            action: #selector(StatusItemController.helpMenuItemClicked),
            keyEquivalent: "")
        helpMenuItem.target = self
        menu.addItem(helpMenuItem)

        let aboutMenuItem = NSMenuItem(
            title: NSLocalizedString("About", comment: "macOS App menu item"),
            action: #selector(StatusItemController.aboutMenuItemClicked),
            keyEquivalent: "")
        aboutMenuItem.target = self
        menu.addItem(aboutMenuItem)

        menu.addItem(NSMenuItem.separator())

        let quitMenuItem = NSMenuItem(
            title: String(format: NSLocalizedString(
                              "Quit %@",
                              comment: "macOS App menu item"),
                          appName),
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
                        $0.connectableInstance?.isEqual(to: activeInstance) ?? false
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

    func updateStatusItemImage() {
        guard let statusItem = statusItem else { return }
        statusItem.button?.image = {
            switch flowStatus {
            case .notConnected, .gettingProfiles, .configuring:
                return shouldUseColorIcons ?
                    NSImage(named: "StatusItemColorNotConnected") :
                    NSImage(named: "StatusItemGrayscaleNotConnected")
            case .connecting, .disconnecting, .reconnecting:
                return shouldUseColorIcons ?
                    NSImage(named: "StatusItemColorConnecting") :
                    NSImage(named: "StatusItemGrayscaleConnecting")
            case .connected:
                return shouldUseColorIcons ?
                    NSImage(named: "StatusItemColorConnected") :
                    NSImage(named: "StatusItemGrayscaleConnected")
            }
        }()
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

        connectionInfoItem = NSMenuItem(
            title: "",
            action: nil,
            keyEquivalent: "")
        connectionInfoItem.isHidden = true
        connectionInfoItem.isEnabled = false

        separatorItem = NSMenuItem.separator()
    }

    func updateStatus(flowStatus: ConnectionViewModel.ConnectionFlowStatus,
                      activeRow: MainViewModel.Row?,
                      controller: StatusItemController) {
        flowStatusItem.title = flowStatus.localizedText
        flowStatusItem.isHidden = false

        activeInstanceItem.title = activeRow?.displayText ?? ""
        activeInstanceItem.isHidden = (activeRow == nil || flowStatus == .notConnected)
    }

    var menuItems: [NSMenuItem] {
        [flowStatusItem, connectionInfoItem, activeInstanceItem, separatorItem]
    }

    func setConnectionInfo(_ string: String?) {
        if let string = string {
            connectionInfoItem.title = string
            connectionInfoItem.isHidden = false
            connectionInfoItem.isEnabled = false
        } else {
            connectionInfoItem.title = ""
            connectionInfoItem.isHidden = true
            connectionInfoItem.isEnabled = false
        }
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
               instance.isEqual(to: activeInstance) {
                entry.menuItem.state = .on
            } else {
                entry.menuItem.state = .off
            }
        }
    }

    func updateIsTogglable(isTogglable: Bool, controller: StatusItemController) {
        for entry in entries where entry.row.rowKind.isServerRow {
            entry.menuItem.isEnabled = isTogglable
            entry.menuItem.target = isTogglable ? controller : nil
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
            return entryConnectableInstance.isEqual(to: connectableInstance)
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

    @objc func connectableInstanceClicked(sender: AnyObject) {
        if let item = sender as? NSMenuItem,
           let row = connectableInstanceEntries.row(for: item),
           let connectableInstance = row.connectableInstance {
            if item.state == .on {
                delegate?.disableVPN()
            } else {
                delegate?.startConnectionFlow(with: connectableInstance)
            }
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

        self.flowStatus = flowStatus
    }

    func mainViewController(
        _ viewController: MainViewController,
        didObserveIsVPNTogglableBecame isTogglable: Bool,
        in connectionViewController: ConnectionViewController) {
        self.connectableInstanceEntries.updateIsTogglable(isTogglable: isTogglable, controller: self)
    }
}

extension StatusItemController: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        isMenuVisible = true
    }
    func menuDidClose(_ menu: NSMenu) {
        isMenuVisible = false
    }
}

extension StatusItemController {
    func updateConnectionInfoState() {
        if flowStatus == .connected && isMenuVisible {
            startShowingConnectionInfo()
        } else {
            stopShowingConnectionInfo()
        }
    }

    func startShowingConnectionInfo() {
        if self.connectionInfoHelper != nil {
            return
        }
        if let connectionService = environment?.connectionService {
            let connectionInfoHelper = StatusItemConnectionInfoHelper(
                connectionService: connectionService,
                handler: { string in
                    self.connectionFlowStatusEntries.setConnectionInfo(string)
                }
            )
            connectionInfoHelper.startUpdating()
            self.connectionInfoHelper = connectionInfoHelper
        }
    }

    func stopShowingConnectionInfo() {
        self.connectionInfoHelper = nil
        self.connectionFlowStatusEntries.setConnectionInfo(nil)
    }
}
#endif
