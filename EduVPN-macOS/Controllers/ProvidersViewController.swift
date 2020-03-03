//
//  ProvidersViewController.swift
//  eduVPN
//

import Cocoa
import os.log
import Alamofire

/// Used to display configure providers (when providerType == .unknown aka. configuredForInstancesDisplay)  and to select a specific provider to add.
class ProvidersViewController: NSViewController {
    
    weak var delegate: ProvidersViewControllerDelegate?
    
    @IBOutlet var tableView: DeselectingTableView!
    @IBOutlet var unreachableLabel: NSTextField?
    
    // Initial VC buttons
    @IBOutlet var otherProviderButton: NSButton?
    @IBOutlet var connectButton: NSButton?
    @IBOutlet var removeButton: NSButton?
    
    // Choose provider VC buttons
    @IBOutlet var backButton: NSButton?
    
    var providerManagerCoordinator: TunnelProviderManagerCoordinator!
    
    var viewContext: NSManagedObjectContext!
    var selectingConfig: Bool = false
    
    var providerType: ProviderType = .unknown

    var configuredForInstancesDisplay: Bool {
        return providerType == .unknown
    }
    
    private var started = false
    
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
        sortDescriptors.append(NSSortDescriptor(key: "providerType", ascending: true))
        // This would be nicer: sortDescriptors.append(NSSortDescriptor(key: "displayName", ascending: true))
        sortDescriptors.append(NSSortDescriptor(key: "baseUri", ascending: true))
        fetchRequest.sortDescriptors = sortDescriptors
        
        let frc = FetchedResultsController<Instance>(fetchRequest: fetchRequest,
                                                     managedObjectContext: viewContext,
                                                     sectionNameKeyPath: "providerType")
        frc.setDelegate(self.frcDelegate)
        
        return frc
    }()
    
    private lazy var frcDelegate: CoreDataFetchedResultsControllerDelegate<Instance> = { // swiftlint:disable:this weak_delegate
        return CoreDataFetchedResultsControllerDelegate<Instance>(tableView: self.tableView, sectioned: true)
    }()
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        refresh()
    }
    
    func start() {
        started = true
        refresh()
    }
    
    @objc func refresh() {
        if !started {
            // Prevent from executing until AppCoordinator assigned all required values
            return
        }
        
        do {
            try fetchedResultsController.performFetch()
            if configuredForInstancesDisplay && rows.isEmpty {
                delegate?.addProvider(providersViewController: self, animated: false)
            }
        } catch {
            os_log("Failed to fetch objects: %{public}@", log: Log.general, type: .error, error.localizedDescription)
        }
    }
    
    private let reachabilityManager = NetworkReachabilityManager(host: "www.eduvpn.org")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Disable while local ovpn file support isn't here yet
        // tableView.registerForDraggedTypes([kUTTypeFileURL as NSPasteboard.PasteboardType,
        //                                    kUTTypeURL as NSPasteboard.PasteboardType])
        
        // Handle internet connection state
        reachabilityManager?.listener = {[weak self] _ in
            self?.updateInterface()
        }
        
        updateInterface()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        tableView.deselectAll(nil)
        tableView.isEnabled = true
        updateInterface()

        reachabilityManager?.startListening()
    }
    
    override func viewWillDisappear() {
        super.viewWillDisappear()
        reachabilityManager?.stopListening()
    }
    
    @IBAction func addOtherProvider(_ sender: Any) {
        delegate?.addProvider(providersViewController: self, animated: true)
    }
    
    private func selectProvider(at row: Int) {
        guard row >= 0 else {
            return
        }
        
        let tableRow = rows[row]
        switch tableRow {
            
        case .section:
            break
            
        case .row(_, let instance):
            delegate?.didSelect(instance: instance, providersViewController: self)
            
        }
    }
    
    @IBAction func connectProvider(_ sender: Any) {
        selectProvider(at: tableView.selectedRow)
    }
    
    @IBAction func connectProviderUsingDoubleClick(_ sender: Any) {
        selectProvider(at: tableView.clickedRow)
    }
    
    @IBAction func removeProvider(_ sender: Any) {
        let row = tableView.selectedRow
        guard row >= 0 else {
            return
        }
        
        let tableRow = rows[row]
        switch tableRow {
            
        case .section:
            break
            
        case .row(_, let instance):
            guard let window = view.window else {
                break
            }
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = NSLocalizedString("Remove \(instance.displayName)?", comment: "")
            alert.informativeText = NSLocalizedString("You will no longer be able to connect to \(instance.displayName).", comment: "")
            
            switch instance.group?.authorizationTypeEnum {
            case .local, .none:
                break
            case .distributed, .federated:
                alert.informativeText += NSLocalizedString(" You may also no longer be able to connect to additional providers that were authorized via this provider.", comment: "")
            }
            
            alert.addButton(withTitle: NSLocalizedString("Remove", comment: ""))
            alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
            alert.beginSheetModal(for: window) { response in
                switch response {
                case NSApplication.ModalResponse.alertFirstButtonReturn:
                    self.tableView.deselectRow(row)
                    self.delegate?.delete(instance: instance)

                default:
                    break
                }
            }
            
        }
    }
    
    private var busy: Bool = false
    
    private func handleError(_ error: Error) {
        if let window = view.window {
            NSAlert(customizedError: error)?.beginSheetModal(for: window)
        }
    }
    
    @IBAction func goBack(_ sender: Any) {
        delegate?.providersViewControllerWantsToClose(self)
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
                
            case .row:
                providerSelected = true
                canRemoveProvider = true
                
            }
        }
        
        let reachable = reachabilityManager?.isReachable ?? true

        unreachableLabel?.isHidden = reachable
        
        tableView.superview?.superview?.isHidden = !reachable
        tableView.isEnabled = !busy
        
        otherProviderButton?.isHidden = providerSelected || !reachable
        otherProviderButton?.isEnabled = !busy
        
        connectButton?.isHidden = !providerSelected || !reachable
        connectButton?.isEnabled = !busy
        
        removeButton?.isHidden = !providerSelected || !reachable
        removeButton?.isEnabled = canRemoveProvider && !busy
    }
}

// MARK: - TableView

extension ProvidersViewController {
    
    fileprivate enum TableRow {
        case section(ProviderType)
        case row(ProviderType, Instance)
    }
    
    fileprivate var rows: [TableRow] {
        var rows: [TableRow] = []
        guard started, let sections = fetchedResultsController.sections else {
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
        // Cancel loading of any previous image load attempts since this view may be reused
        ImageLoader.cancelLoadImage(target: cellView.imageView)
        cellView.imageView?.image = nil
        cellView.imageView?.isHidden = false
        
        switch providerType {
            
        case .instituteAccess, .secureInternet:
            if let logoString = instance.logos?.localizedValue, let logoUrl = URL(string: logoString) {
                ImageLoader.loadImage(logoUrl, target: cellView.imageView)
            } else {
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
        switch providerType {
        case .unknown:
            updateInterface()
        default:
            guard tableView.selectedRow >= 0 else {
                return
            }

            selectProvider(at: tableView.selectedRow)

            tableView.deselectRow(tableView.selectedRow)
            
            updateInterface()
        }
    }
    
    func tableView(_ tableView: NSTableView,
                   validateDrop info: NSDraggingInfo,
                   proposedRow row: Int,
                   proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        
        tableView.setDropRow(-1, dropOperation: .on)
        return .copy
    }
    
    // Drag and drop currently not supported
//    func tableView(_ tableView: NSTableView,
//                   acceptDrop info: NSDraggingInfo,
//                   row: Int,
//                   dropOperation: NSTableView.DropOperation) -> Bool {
//
//        guard let url = NSURL(from: info.draggingPasteboard) else {
//            return false
//        }
//
//        delegate?.addCustomProviderWithUrl(url as URL)
//
//        return true
//    }
    
}
