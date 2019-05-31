//
//  ProvidersViewController.swift
//  eduVPN
//
//  Created by Johan Kool on 16/10/2017.
//  Copyright © 2017-2019 Commons Conservancy.
//

import Cocoa
import Kingfisher
import os.log
import Reachability

class ProvidersViewController: NSViewController {
    
    weak var delegate: ProvidersViewControllerDelegate?

    @IBOutlet var tableView: DeselectingTableView!
    @IBOutlet var unreachableLabel: NSTextField!
    @IBOutlet var otherProviderButton: NSButton!
    @IBOutlet var connectButton: NSButton!
    @IBOutlet var removeButton: NSButton!
    
    var providerManagerCoordinator: TunnelProviderManagerCoordinator!
    
    var viewContext: NSManagedObjectContext!
    var selectingConfig: Bool = false
    
    var providerType: ProviderType = .unknown
    
    private lazy var fetchedResultsController: FetchedResultsController<Instance> = {
        let fetchRequest = NSFetchRequest<Instance>()
        fetchRequest.entity = Instance.entity()
        
        switch providerType {
            
        case .unknown:
            fetchRequest.predicate = NSPredicate(format: "apis.@count > 0 AND (SUBQUERY(apis, $y, (SUBQUERY($y.profiles, $z, $z != NIL).@count > 0)).@count > 0)")
            
        default:
            fetchRequest.predicate = NSPredicate(format: "providerType == %@", providerType.rawValue)
            
        }
        
        var sortDescriptors = [NSSortDescriptor]()
        if Config.shared.discovery != nil {
            sortDescriptors.append(NSSortDescriptor(key: "providerType", ascending: true))
        }
        
        sortDescriptors.append(NSSortDescriptor(key: "baseUri", ascending: true))
        fetchRequest.sortDescriptors = sortDescriptors
        
        let frc = FetchedResultsController<Instance>(fetchRequest: fetchRequest,
                                                     managedObjectContext: viewContext,
                                                     sectionNameKeyPath: Config.shared.discovery != nil ? "providerType": nil)
        frc.setDelegate(self.frcDelegate)
        
        return frc
    }()
    
    private lazy var frcDelegate: CoreDataFetchedResultsControllerDelegate<Instance> = { // swiftlint:disable:this weak_delegate
        return CoreDataFetchedResultsControllerDelegate<Instance>(tableView: self.tableView)
    }()
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        refresh()
    }
    
    @objc func refresh() {
        do {
            try fetchedResultsController.performFetch()
        } catch {
            os_log("Failed to fetch objects: %{public}@", log: Log.general, type: .error, error.localizedDescription)
        }
    }
    
    private let reachability = Reachability()
  
    override func viewDidLoad() {
        super.viewDidLoad()
                
        // Close orphaned connection
        busy = true
        //         <UNCOMMENT>
//        ServiceContainer.connectionService.closeOrphanedConnectionIfNeeded { _ in
//            self.busy = false
//            self.updateInterface()
//        }
        // </UNCOMMENT>
        
        tableView.registerForDraggedTypes([kUTTypeFileURL as NSPasteboard.PasteboardType,
                                           kUTTypeURL as NSPasteboard.PasteboardType])
        
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
        
        // <UNCOMMENT>
//        if !ServiceContainer.providerService.hasAtLeastOneStoredProvider {
//            addOtherProvider(animated: false)
//        }
        // </UNCOMMENT>
        
        discoverAccessibleProviders()
        try? reachability?.startNotifier()
    }
    
    override func viewWillDisappear() {
        super.viewWillDisappear()
        reachability?.stopNotifier()
    }
    
    private func discoverAccessibleProviders() {
        // <UNCOMMENT>
//        ServiceContainer.providerService.discoverAccessibleProviders { result in
//            DispatchQueue.main.async {
//                switch result {
//
//                case .success(let providers):
//                    self.providers = providers
//                    self.tableView.reloadData()
//                    self.updateInterface()
//
//                case .failure(let error):
//                    NSAlert(customizedError: error)?.beginSheetModal(for: self.view.window!)
//
//                }
//            }
//        }
        // </UNCOMMENT>
    }
    
    @IBAction func addOtherProvider(_ sender: Any) {
        addOtherProvider(animated: true)
    }
    
    private func addOtherProvider(animated: Bool) {
        // <UNCOMMENT>
        mainWindowController?.showChooseConnectionType(allowClose: !rows.isEmpty, animated: animated)
        // </UNCOMMENT>
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
        // <UNCOMMENT>
        case .row(_, let instance):
            break
//            authenticateAndConnect(to: instance)
            // </UNCOMMENT>
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
        case .row(_, let instance):
            break
//            authenticateAndConnect(to: instance)
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
        case .row(let providerType, let instance):
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = NSLocalizedString("Remove \(instance.displayName)?", comment: "")
            alert.informativeText = NSLocalizedString("You will no longer be able to connect to \(providerType.title).", comment: "")
            
            switch instance.group!.authorizationTypeEnum {
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
                    // <UNCOMMENT>
//                    ServiceContainer.providerService.deleteProvider(provider: provider)
                    // </UNCOMMENT>
                    self.discoverAccessibleProviders()
                default:
                    break
                }
            }
        }
    }
    
    private var busy: Bool = false
    
    // <UNCOMMENT>
//    fileprivate func authenticateAndConnect(to instance: Instance) {
//        if let authState = ServiceContainer.authenticationService.authState(for: provider), authState.isAuthorized {
//            busy = true
//            updateInterface()
//
//            ServiceContainer.providerService.fetchInfo(for: provider) { result in
//                DispatchQueue.main.async {
//                    self.busy = false
//                    self.updateInterface()
//
//                    switch result {
//                    case .success(let info):
//                        self.fetchProfiles(for: info)
//                    case .failure(let error):
//                        self.handleError(error)
//                    }
//                }
//            }
//        } else {
//            // No (valid) authentication token
//            busy = true
//            updateInterface()
//
//            ServiceContainer.providerService.fetchInfo(for: provider) { result in
//                DispatchQueue.main.async {
//                    self.busy = false
//                    self.updateInterface()
//
//                    switch result {
//                    case .success(let info):
//                        self.authenticate(with: info)
//                    case .failure(let error):
//                        self.handleError(error)
//                    }
//                }
//            }
//        }
//    }
//
//
//    private func authenticate(with info: ProviderInfo) {
//        busy = true
//        updateInterface()
//        ServiceContainer.authenticationService.authenticate(using: info) { result in
//            DispatchQueue.main.async {
//
//                self.busy = false
//                self.updateInterface()
//
//                switch result {
//                case .success:
//                    ServiceContainer.providerService.storeProvider(provider: info.provider)
//                    self.fetchProfiles(for: info)
//                case .failure(let error):
//                    self.handleError(error)
//                }
//            }
//        }
//    }
//
//    private func fetchProfiles(for info: ProviderInfo) {
//        busy = true
//        updateInterface()
//
//        ServiceContainer.providerService.fetchUserInfoAndProfiles(for: info) { result in
//            DispatchQueue.main.async {
//                self.busy = false
//                self.updateInterface()
//
//                switch result {
//                case .success(let userInfo, let profiles):
//                    if profiles.count == 1 {
//                        let profile = profiles[0]
//                        self.mainWindowController?.showConnection(for: profile, userInfo: userInfo)
//                    } else {
//                        // Choose profile
//                        self.mainWindowController?.showChooseProfile(from: profiles, userInfo: userInfo)
//                    }
//                case .failure(let error):
//                    self.handleError(error)
//                }
//            }
//        }
//    }
    // </UNCOMMENT>
    
    private func handleError(_ error: Error) {
        NSAlert(customizedError: error)?.beginSheetModal(for: self.view.window!)
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
                
            case .row(_, let instance):
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

// MARK - TableView

extension ProvidersViewController {
    
    fileprivate enum TableRow {
        case section(ProviderType)
        case row(ProviderType, Instance)
    }
    
    fileprivate var rows: [TableRow] {
        var rows: [TableRow] = []
        guard let sections = fetchedResultsController.sections else {
            return rows
        }
        
        sections.forEach { section in
            let providerType: ProviderType
            if let sectionName = section.name {
                providerType = ProviderType(rawValue: sectionName) ?? .unknown
            } else {
                providerType = .unknown
            }
            
            rows.append(.section(providerType))
            section.objects.forEach { instance in
                rows.append(.row(providerType, instance))
            }
        }
        
        return rows
    }
}

extension ProvidersViewController: NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return rows.count
    }
}

extension ProvidersViewController: NSTableViewDelegate {
    
    private func configureSectionCellView(_ cellView: NSTableCellView, providerType: ProviderType) {
        cellView.textField?.stringValue = providerType.title
    }
    
    private func configureRowCellView(_ cellView: NSTableCellView, providerType: ProviderType, instance: Instance) {
        cellView.imageView?.isHidden = false
        
        switch providerType {
            
        case .instituteAccess, .secureInternet:
            if let logoString = instance.logos?.localizedValue, let logoUrl = URL(string: logoString) {
                cellView.imageView?.kf.setImage(with: logoUrl)
            } else {
                cellView.imageView?.kf.cancelDownloadTask()
                cellView.imageView?.image = nil
                cellView.imageView?.isHidden = true
            }
            
        case .other:
            cellView.imageView?.image = NSWorkspace.shared.icon(forFileType: NSFileTypeForHFSTypeCode(OSType(kGenericNetworkIcon)))
            
        case .local:
            cellView.imageView?.image = NSWorkspace.shared.icon(forFileType: NSFileTypeForHFSTypeCode(OSType(kGenericDocumentIcon)))
            
        case .unknown:
            cellView.imageView?.image = nil
            cellView.imageView?.isHidden = true
            
        }
        
        cellView.textField?.stringValue = instance.displayName
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let tableRow = rows[row]
        
        switch tableRow {
            
        case .section(let providerType):
            let cellView = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "SectionCell"),
                                              owner: self)
            
            if let cellView = cellView as? NSTableCellView {
                configureSectionCellView(cellView, providerType: providerType)
            }
            
            return cellView
            
        case .row(let providerType, let instance):
            let cellView = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "ProfileCell"),
                                              owner: self)
            
            if let cellView = cellView as? NSTableCellView {
                configureRowCellView(cellView, providerType: providerType, instance: instance)
            }
            
            return cellView
        }
    }
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        let tableRow = rows[row]
        switch tableRow {
        case .section:
            return false
        case .row:
            return true
        }
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        updateInterface()
    }
    
    func tableView(_ tableView: NSTableView,
                   validateDrop info: NSDraggingInfo,
                   proposedRow row: Int,
                   proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        
        tableView.setDropRow(-1, dropOperation: .on)
        return .copy
    }
    
    func tableView(_ tableView: NSTableView,
                   acceptDrop info: NSDraggingInfo,
                   row: Int,
                   dropOperation: NSTableView.DropOperation) -> Bool {
        
        guard let url = NSURL(from: info.draggingPasteboard) else {
            return false
        }
        
        if url.isFileURL {
            chooseConfigFile(configFileURL: url as URL)
        } else {
            delegate?.addCustomProviderWithUrl(url as URL)
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
                    
                    alert?.beginSheetModal(for: self.view.window!) { response in
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
}

protocol ProvidersViewControllerDelegate: class {
    func addProvider(providersViewController: ProvidersViewController)
    func addPredefinedProvider(providersViewController: ProvidersViewController)
    func didSelect(instance: Instance, providersViewController: ProvidersViewController)
    func settings(providersViewController: ProvidersViewController)
    func delete(instance: Instance)
    func addCustomProviderWithUrl(_ url: URL)
}
