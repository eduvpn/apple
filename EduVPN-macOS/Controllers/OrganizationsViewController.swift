//
//  OrganizationsViewController.swift
//  eduVPN
//

import Cocoa
import os.log
import Alamofire

protocol OrganizationsViewControllerDelegate: class {
    func organizationsViewController(_ controller: OrganizationsViewController, didSelect organization: Organization)
    func organizationsViewControllerShouldClose(_ controller: OrganizationsViewController)
    func organizationsViewControllerWantsToAddUrl(_ controller: OrganizationsViewController)
}

/// Used to display and search all available organizations and to select a specific organization to add.
class OrganizationsViewController: NSViewController {
    
    weak var delegate: OrganizationsViewControllerDelegate?
    
    private var allowClose = true {
        didSet {
            guard isViewLoaded else {
                return
            }
            backButton?.isHidden = !allowClose
        }
    }
    
    func allowClose(_ state: Bool) {
        self.allowClose = state
    }
    
    @IBOutlet var tableView: DeselectingTableView!
    @IBOutlet var unreachableLabel: NSTextField?
    
    // Initial VC buttons
    @IBOutlet var otherProviderButton: NSButton?
    @IBOutlet weak var searchField: NSSearchField!
    
    // Choose organization VC buttons
    @IBOutlet var backButton: NSButton?
        
    var viewContext: NSManagedObjectContext!
    
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
    
    @objc func refresh() {
        do {
            let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !query.isEmpty {
                fetchedResultsController.fetchRequest.predicate = NSPredicate(format: "displayName CONTAINS[cd] %@ OR keyword CONTAINS[cd] %@", query, query)
            } else {
                fetchedResultsController.fetchRequest.predicate = nil
            }
            try fetchedResultsController.performFetch()
        } catch {
            os_log("Failed to fetch objects: %{public}@", log: Log.general, type: .error, error.localizedDescription)
        }
    }
    
    private let reachabilityManager = NetworkReachabilityManager(host: "www.eduvpn.org")
    
    override func viewDidLoad() {
        super.viewDidLoad()
         
         (allowClose = allowClose)
        
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
        guard rows.indices.contains(row) else {
            return
        }
        
        let tableRow = rows[row]
        switch tableRow {
        case .row(let organization):
            delegate?.organizationsViewController(self, didSelect: organization)
        }
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
        let reachable = reachabilityManager?.isReachable ?? true

        unreachableLabel?.isHidden = reachable
        
        tableView.superview?.superview?.isHidden = !reachable
        tableView.isEnabled = !busy
        
        otherProviderButton?.isHidden = !reachable
        otherProviderButton?.isEnabled = !busy
    }
}

// MARK: - TableView

extension OrganizationsViewController {
    
    fileprivate enum TableRow {
        case row(Organization)
    }
    
    fileprivate var rows: [TableRow] {
        var rows: [TableRow] = []
        guard let sections = fetchedResultsController.sections else {
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
    
    private func configureRowCellView(_ cellView: NSTableCellView, organization: Organization) {
        cellView.textField?.stringValue = organization.displayName ?? ""
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let tableRow = rows[row]
        
        switch tableRow {
        case .row(let organization):
            let cellView = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "OrganizationCell"), owner: self)
            
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
    
}
