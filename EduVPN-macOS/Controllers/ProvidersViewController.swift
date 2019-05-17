//
//  ProvidersViewController.swift
//  eduVPN
//
//  Created by Johan Kool on 16/10/2017.
//  Copyright © 2017-2019 Commons Conservancy.
//

import Cocoa
import AppAuth
import Reachability

class ProvidersViewController: NSViewController {

    @IBOutlet var tableView: DeselectingTableView!
    @IBOutlet var unreachableLabel: NSTextField!
    @IBOutlet var otherProviderButton: NSButton!
    @IBOutlet var connectButton: NSButton!
    @IBOutlet var removeButton: NSButton!
    
    private var providers: [ConnectionType: [Provider]]! {
        didSet {
            var rows: [TableRow] = []
            
            func addRows(connectionType: ConnectionType) {
                if let connectionProviders = providers[connectionType], !connectionProviders.isEmpty {
                    rows.append(.section(connectionType))
                    connectionProviders.forEach { (provider) in
                        rows.append(.provider(provider))
                    }
                }
            }
            
            addRows(connectionType: .secureInternet)
            addRows(connectionType: .instituteAccess)
            addRows(connectionType: .custom)
            addRows(connectionType: .localConfig)
            
            self.rows = rows
        }
    }
    
    private enum TableRow {
        case section(ConnectionType)
        case provider(Provider)
    }
    
    private var rows: [TableRow] = []
    private let reachability = Reachability()
  
    override func viewDidLoad() {
        super.viewDidLoad()
                
        // Close orphaned connection
        busy = true
        ServiceContainer.connectionService.closeOrphanedConnectionIfNeeded { _ in
            self.busy = false
            self.updateInterface()
        }
        
        tableView.registerForDraggedTypes([kUTTypeFileURL as NSPasteboard.PasteboardType, kUTTypeURL as NSPasteboard.PasteboardType])
        
        // Handle internet connection state
        if let reachability = reachability {
            reachability.whenReachable = { [weak self] reachability in
                self?.discoverAccessibleProviders()
                self?.updateInterface()
            }
            
            reachability.whenUnreachable = { [weak self] _ in
                self?.updateInterface()
            }
        } else {
            discoverAccessibleProviders()
        }
        updateInterface()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        tableView.deselectAll(nil)
        tableView.isEnabled = true
        
        if !ServiceContainer.providerService.hasAtLeastOneStoredProvider {
            addOtherProvider(animated: false)
        }
        
        discoverAccessibleProviders()
        try? reachability?.startNotifier()
    }
    
    override func viewWillDisappear() {
        super.viewWillDisappear()
        reachability?.stopNotifier()
    }
    
    private func discoverAccessibleProviders() {
        ServiceContainer.providerService.discoverAccessibleProviders { (result) in
            DispatchQueue.main.async {
                switch result {
                case .success(let providers):
                    self.providers = providers
                    self.tableView.reloadData()
                    self.updateInterface()
                case .failure(let error):
                    let alert = NSAlert(customizedError: error)
                    alert?.beginSheetModal(for: self.view.window!) { (_) in
                        
                    }
                }
            }
        }
    }
    
    @IBAction func addOtherProvider(_ sender: Any) {
        addOtherProvider(animated: true)
    }
    
    private func addOtherProvider(animated: Bool) {
        mainWindowController?.showChooseConnectionType(allowClose: !rows.isEmpty, animated: animated)
    }
    
    @IBAction func connectProvider(_ sender: Any) {
        let row = tableView.selectedRow
        guard row >= 0 else {
            return
        }
        
        let tableRow = rows[row]
        switch tableRow {
        case .section:
            // Ignore
            break
        case .provider(let provider):
            authenticateAndConnect(to: provider)
        }
    }
    
    @IBAction func connectProviderUsingDoubleClick(_ sender: Any) {
        let row = tableView.clickedRow
        guard row >= 0 else {
            return
        }
        
        let tableRow = rows[row]
        switch tableRow {
        case .section:
            // Ignore
            break
        case .provider(let provider):
            authenticateAndConnect(to: provider)
        }
    }
    
    @IBAction func removeProvider(_ sender: Any) {
        let row = tableView.selectedRow
        guard row >= 0 else {
            return
        }
        
        let tableRow = rows[row]
        switch tableRow {
        case .section:
            // Ignore
            break
        case .provider(let provider):
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = NSLocalizedString("Remove \(provider.displayName)?", comment: "")
            alert.informativeText = NSLocalizedString("You will no longer be able to connect to \(provider.displayName).", comment: "")
            switch provider.authorizationType {
            case .local:
                break
            case .distributed, .federated:
                alert.informativeText += NSLocalizedString(" You may also no longer be able to connect to additional providers that were authorized via this provider.", comment: "")
            }
            alert.addButton(withTitle: NSLocalizedString("Remove", comment: ""))
            alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
            alert.beginSheetModal(for: self.view.window!) { response in
                switch response {
                case NSApplication.ModalResponse.alertFirstButtonReturn:
                    ServiceContainer.providerService.deleteProvider(provider: provider)
                    self.discoverAccessibleProviders()
                default:
                    break
                }
            }
        }
    }
    
    private var busy: Bool = false
    
    fileprivate func authenticateAndConnect(to provider: Provider) {
        if let authState = ServiceContainer.authenticationService.authState(for: provider), authState.isAuthorized {
            busy = true
            updateInterface()
            
            ServiceContainer.providerService.fetchInfo(for: provider) { (result) in
                DispatchQueue.main.async {
                    self.busy = false
                    self.updateInterface()
                    
                    switch result {
                    case .success(let info):
                        self.fetchProfiles(for: info)
                    case .failure(let error):
                        self.handleError(error)
                    }
                }
            }
        } else {
            // No (valid) authentication token
            busy = true
            updateInterface()
            
            ServiceContainer.providerService.fetchInfo(for: provider) { (result) in
                DispatchQueue.main.async {
                    self.busy = false
                    self.updateInterface()
                    
                    switch result {
                    case .success(let info):
                        self.authenticate(with: info)
                    case .failure(let error):
                        self.handleError(error)
                    }
                }
            }
        }
    }
    
    
    private func authenticate(with info: ProviderInfo) {
        busy = true
        updateInterface()
        ServiceContainer.authenticationService.authenticate(using: info) { (result) in
            DispatchQueue.main.async {
                
                self.busy = false
                self.updateInterface()
                
                switch result {
                case .success:
                    ServiceContainer.providerService.storeProvider(provider: info.provider)
                    self.fetchProfiles(for: info)
                case .failure(let error):
                    self.handleError(error)
                }
            }
        }
    }

    private func fetchProfiles(for info: ProviderInfo) {
        busy = true
        updateInterface()
        
        ServiceContainer.providerService.fetchUserInfoAndProfiles(for: info) { (result) in
            DispatchQueue.main.async {
                self.busy = false
                self.updateInterface()
                
                switch result {
                case .success(let userInfo, let profiles):
                    if profiles.count == 1 {
                        let profile = profiles[0]
                        self.mainWindowController?.showConnection(for: profile, userInfo: userInfo)
                    } else {
                        // Choose profile
                        self.mainWindowController?.showChooseProfile(from: profiles, userInfo: userInfo)
                    }
                case .failure(let error):
                    self.handleError(error)
                }
            }
        }
    }
    
    private func handleError(_ error: Error) {
        let alert = NSAlert(customizedError: error)
        alert?.beginSheetModal(for: self.view.window!) { (_) in
            // Nothing
        }
    }
    
    fileprivate func updateInterface() {
        let row = tableView.selectedRow
        let providerSelected: Bool
        let canRemoveProvider: Bool
        
        if row < 0 {
            providerSelected = false
            canRemoveProvider = false
        } else {
            let tableRow = rows[row]
            switch tableRow {
            case .section:
                providerSelected = false
                canRemoveProvider = false
            case .provider(let provider):
                providerSelected = true
                canRemoveProvider = ServiceContainer.providerService.storedProviders[provider.connectionType]?.contains(where: { $0.id == provider.id }) ?? false
            }
        }
        
        let reachable: Bool
        if let reachability = reachability {
            reachable = reachability.connection != .none
        } else {
            reachable = true
        }
    
        unreachableLabel.isHidden = reachable
        tableView.superview?.superview?.isHidden = !reachable
        tableView.isEnabled = !busy
        otherProviderButton.isHidden = providerSelected || !reachable
        otherProviderButton.isEnabled = !busy
        connectButton.isHidden = !providerSelected || !reachable
        connectButton.isEnabled = !busy
        removeButton.isHidden = !providerSelected || !reachable
        removeButton.isEnabled = canRemoveProvider && !busy
    }
}

extension ProvidersViewController: NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return rows.count
    }
    
}

extension ProvidersViewController: NSTableViewDelegate {
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let tableRow = rows[row]
        switch tableRow {
        case .section(let connectionType):
            let result = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "SectionCell"), owner: self) as? NSTableCellView
            result?.textField?.stringValue = connectionType.localizedDescription
            return result
        case .provider(let provider):
            let result = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "ProfileCell"), owner: self) as? NSTableCellView
            switch provider.connectionType {
            case .instituteAccess, .secureInternet:
                result?.imageView?.kf.setImage(with: provider.logoURL)
            case .custom:
                result?.imageView?.image = NSWorkspace.shared.icon(forFileType: NSFileTypeForHFSTypeCode(OSType(kGenericNetworkIcon)))
            case .localConfig:
                result?.imageView?.image = NSWorkspace.shared.icon(forFileType: NSFileTypeForHFSTypeCode(OSType(kGenericDocumentIcon)))
            }
            
            result?.textField?.stringValue = provider.displayName
            return result
        }
    }
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        let tableRow = rows[row]
        switch tableRow {
        case .section:
            return false
        case .provider:
            return true
        }
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        updateInterface()
    }
    
    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        tableView.setDropRow(-1, dropOperation: .on)
        return .copy
    }
    
    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        guard let url = NSURL(from: info.draggingPasteboard) else {
            return false
        }
        
        if url.isFileURL {
            chooseConfigFile(configFileURL: url as URL)
        } else {
            addURL(baseURL: url as URL)
        }
        return true
    }
    
    private func chooseConfigFile(configFileURL: URL, recover: Bool = false) {
        ServiceContainer.providerService.addProvider(configFileURL: configFileURL, recover: recover) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.discoverAccessibleProviders()
                case .failure(let error):
                    let alert = NSAlert(customizedError: error)
                    if let error = error as? ProviderService.Error, !error.recoveryOptions.isEmpty {
                        error.recoveryOptions.forEach {
                            alert?.addButton(withTitle: $0)
                        }
                    }
                    
                    alert?.beginSheetModal(for: self.view.window!) { (response) in
                        switch response.rawValue {
                        case 1000:
                            self.chooseConfigFile(configFileURL: configFileURL, recover: true)
                        default:
                            break
                        }
                    }
                }
            }
        }
    }
    
    private func addURL(baseURL: URL) {
        let provider = Provider(displayName: baseURL.host ?? "", baseURL: baseURL, logoURL: nil, publicKey: nil, username: nil, connectionType: .custom, authorizationType: .local)
        ServiceContainer.providerService.fetchInfo(for: provider) { result in
            switch result {
            case .success(let info):
                DispatchQueue.main.async {
                    ServiceContainer.providerService.storeProvider(provider: info.provider)
                     self.discoverAccessibleProviders()
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    let alert = NSAlert(customizedError: error)
                    alert?.beginSheetModal(for: self.view.window!) { (_) in
                        
                    }
                }
            }
        }
    }
    
}

class DeselectingTableView: NSTableView {
    
    override open func mouseDown(with event: NSEvent) {
        let beforeIndex = selectedRow
        
        super.mouseDown(with: event)
        
        let point = convert(event.locationInWindow, from: nil)
        let rowIndex = row(at: point)
        
        if rowIndex < 0 {
            deselectAll(nil)
        } else if rowIndex == beforeIndex {
            deselectRow(rowIndex)
        } else if let delegate = delegate {
            if !delegate.tableView!(self, shouldSelectRow: rowIndex) {
                deselectAll(nil)
            }
        }
    }
    
}
