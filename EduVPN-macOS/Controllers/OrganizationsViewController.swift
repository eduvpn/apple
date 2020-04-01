//
//  OrganizationsViewController.swift
//  eduVPN
//

import Cocoa
import os.log
import Alamofire

protocol OrganizationsViewControllerDelegate: class {
    func organizationsViewControllerNoProfiles(_ controller: OrganizationsViewController)
    func organizationsViewController(_ controller: OrganizationsViewController, addProviderAnimated animated: Bool)
    func organizationsViewControllerAddPredefinedProvider(_ controller: OrganizationsViewController)
    func organizationsViewController(_ controller: OrganizationsViewController, didSelect instance: Organization)
    func organizationsViewController(_ controller: OrganizationsViewController, didDelete instance: Organization)
    func organizationsViewControllerShouldClose(_ controller: OrganizationsViewController)
    func organizationsViewController(_ controller: OrganizationsViewController, addCustomProviderWithUrl url: URL)
    func organizationsViewControllerWantsToAddUrl(_ controller: OrganizationsViewController)
}

/// Used to display configure organizations (when organizationType == .unknown aka. configuredForInstancesDisplay)  and to select a specific organization to add.
class OrganizationsViewController: NSViewController {
    
    weak var delegate: OrganizationsViewControllerDelegate?
    
    @IBOutlet var tableView: DeselectingTableView!
    @IBOutlet var unreachableLabel: NSTextField?
    
    // Initial VC buttons
    @IBOutlet var otherProviderButton: NSButton?
    @IBOutlet var connectButton: NSButton?
    @IBOutlet var removeButton: NSButton?
    @IBOutlet weak var searchField: NSSearchField!
    
    // Choose organization VC buttons
    @IBOutlet var backButton: NSButton?
        
    var viewContext: NSManagedObjectContext!

    private var started = false
    
    private lazy var fetchedResultsController: FetchedResultsController<Organization> = {
        let fetchRequest = NSFetchRequest<Organization>()
        fetchRequest.entity = Organization.entity()
        
        var sortDescriptors = [NSSortDescriptor]()
        sortDescriptors.append(NSSortDescriptor(key: "displayName", ascending: true))
        fetchRequest.sortDescriptors = sortDescriptors
        
        let frc = FetchedResultsController<Organization>(fetchRequest: fetchRequest,
                                                     managedObjectContext: viewContext)
        frc.setDelegate(self.frcDelegate)
        
        return frc
    }()
    
    private lazy var frcDelegate: CoreDataFetchedResultsControllerDelegate<Organization> = { // swiftlint:disable:this weak_delegate
        return CoreDataFetchedResultsControllerDelegate<Organization>(tableView: self.tableView, sectioned: true)
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
            let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !query.isEmpty {
                fetchedResultsController.fetchRequest.predicate = NSPredicate(format: "displayName CONTAINS[cd] %@ OR keyword CONTAINS[cd] %@", query, query)
            } else {
                fetchedResultsController.fetchRequest.predicate = nil
            }
            try fetchedResultsController.performFetch()
//            if configuredForInstancesDisplay && rows.isEmpty {
//                delegate?.organizationsViewController(self, addProviderAnimated: false)
//            }
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
        
        searchField.becomeFirstResponder()
    }
    
    override func viewWillDisappear() {
        super.viewWillDisappear()
        reachabilityManager?.stopListening()
    }
    
    @IBAction func enterProviderURL(_ sender: Any) {
        delegate?.organizationsViewControllerWantsToAddUrl(self)
    }
    
    @IBAction func search(_ sender: Any) {
        refresh()
    }
    
    private func selectProvider(at row: Int) {
        guard row >= 0 else {
            return
        }
        
        let tableRow = rows[row]
        switch tableRow {
            
        case .row(let instance):
            delegate?.organizationsViewController(self, didSelect: instance)
            
        }
    }
    
    @IBAction func connectProvider(_ sender: Any) {
        selectProvider(at: tableView.selectedRow)
    }
    
    @IBAction func connectProviderUsingDoubleClick(_ sender: Any) {
        selectProvider(at: tableView.clickedRow)
    }
    
    private var busy: Bool = false
    
    private func handleError(_ error: Error) {
        if let window = view.window {
            NSAlert(customizedError: error)?.beginSheetModal(for: window)
        }
    }
    
    @IBAction func goBack(_ sender: Any) {
        delegate?.organizationsViewControllerShouldClose(self)
    }
    
    fileprivate func updateInterface() {
        let row = tableView.selectedRow
        let organizationSelected: Bool
        let canRemoveProvider: Bool
        
        if row < 0 {
            organizationSelected = false
            canRemoveProvider = false
        } else {
            let tableRow = rows[row]
            
            switch tableRow {
        
            case .row:
                organizationSelected = true
                canRemoveProvider = true
                
            }
        }
        
        let reachable = reachabilityManager?.isReachable ?? true

        unreachableLabel?.isHidden = reachable
        
        tableView.superview?.superview?.isHidden = !reachable
        tableView.isEnabled = !busy
        
        otherProviderButton?.isHidden = organizationSelected || !reachable
        otherProviderButton?.isEnabled = !busy
        
        connectButton?.isHidden = !organizationSelected || !reachable
        connectButton?.isEnabled = !busy
        
        removeButton?.isHidden = !organizationSelected || !reachable
        removeButton?.isEnabled = canRemoveProvider && !busy
    }
}

// MARK: - TableView

extension OrganizationsViewController {
    
    fileprivate enum TableRow {
        case row(Organization)
    }
    
    fileprivate var rows: [TableRow] {
        var rows: [TableRow] = []
        guard started, let sections = fetchedResultsController.sections else {
            return rows
        }
        
        sections.forEach { section in
            section.objects.forEach { instance in
                rows.append(.row(instance))
            }
        }
        
        return rows
    }
}

extension OrganizationsViewController: NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return rows.count
    }
}

extension OrganizationsViewController: NSTableViewDelegate {
    
    private func configureSectionCellView(_ cellView: NSTableCellView, organizationType: ProviderType) {
        cellView.textField?.stringValue = organizationType.title
    }
    
    private func configureRowCellView(_ cellView: NSTableCellView, organization: Organization) {
        // Cancel loading of any previous image load attempts since this view may be reused
        ImageLoader.cancelLoadImage(target: cellView.imageView)
        cellView.imageView?.image = nil
        cellView.imageView?.isHidden = true
        
        cellView.textField?.stringValue = organization.displayName ?? ""
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let tableRow = rows[row]
        
        switch tableRow {
        case .row(let organization):
            let cellView = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "OrganizationCell"),
                                              owner: self)
            
            if let cellView = cellView as? NSTableCellView {
                configureRowCellView(cellView, organization: organization)
            }
            
            return cellView
        }
    }
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        let tableRow = rows[row]
        switch tableRow {
        case .row:
            return true
        }
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        guard tableView.selectedRow >= 0 else {
            return
        }
        
        selectProvider(at: tableView.selectedRow)
        
        tableView.deselectRow(tableView.selectedRow)
        
        updateInterface()
    }
    
    func tableView(_ tableView: NSTableView,
                   validateDrop info: NSDraggingInfo,
                   proposedRow row: Int,
                   proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        
        tableView.setDropRow(-1, dropOperation: .on)
        return .copy
    }
    
}
