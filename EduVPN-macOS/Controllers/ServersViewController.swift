//
//  ServersViewController.swift
//  eduVPN
//

import Cocoa
import os.log
import Alamofire

protocol ServersViewControllerDelegate: class {
    func serversViewControllerNoProfiles(_ controller: ServersViewController)
    func serversViewController(_ controller: ServersViewController, addProviderAnimated animated: Bool, allowClose: Bool)
    func serversViewControllerAddPredefinedProvider(_ controller: ServersViewController)
    func serversViewController(_ controller: ServersViewController, didSelect server: Server)
    func serversViewController(_ controller: ServersViewController, didDelete server: Server)
    func serversViewController(_ controller: ServersViewController, didDelete organization: Organization)
}

/// Used to display configured servers grouped by organization (or custom/local)
class ServersViewController: NSViewController {
    
    weak var delegate: ServersViewControllerDelegate?
    
    @IBOutlet var tableView: DeselectingTableView!
    @IBOutlet var unreachableLabel: NSTextField?
    
    @IBOutlet var otherProviderButton: NSButton?
    @IBOutlet var connectButton: NSButton?
    @IBOutlet var removeButton: NSButton?
        
    var viewContext: NSManagedObjectContext!
    
    private var started = false
    
    private lazy var fetchedResultsController: FetchedResultsController<Server> = {
        let fetchRequest = NSFetchRequest<Server>()
        fetchRequest.entity = Server.entity()
        fetchRequest.predicate = NSPredicate(format: "provider != NIL AND (isParent == TRUE OR parent.isExpanded == TRUE)")
        
        let sortDescriptors = [NSSortDescriptor(key: "sortName", ascending: true)]
        fetchRequest.sortDescriptors = sortDescriptors
        
        let frc = FetchedResultsController<Server>(fetchRequest: fetchRequest,
                                                   managedObjectContext: viewContext,
                                                   sectionNameKeyPath: "provider.groupName")
        frc.setDelegate(self.frcDelegate)
        
        return frc
    }()
    
    private lazy var frcDelegate: CoreDataFetchedResultsControllerDelegate<Server> = { // swiftlint:disable:this weak_delegate
        return CoreDataFetchedResultsControllerDelegate<Server>(tableView: self.tableView, sectioned: true)
    }()
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        refresh(animated: false)
    }
    
    func start() {
        started = true
        refresh(animated: false)
    }
    
    @objc func refresh(animated: Bool) {
        if !started {
            // Prevent from executing until AppCoordinator assigned all required values
            return
        }
        
        do {
            try fetchedResultsController.performFetch()
            updateInterface()
            
            if rows.isEmpty {
                delegate?.serversViewController(self, addProviderAnimated: animated, allowClose: false)
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
        delegate?.serversViewController(self, addProviderAnimated: true, allowClose: true)
    }
    
    private func selectProvider(at row: Int) {
        guard row >= 0 else {
            return
        }
        
        let tableRow = rows[row]
        switch tableRow {
            
        case .section:
            break
            
        case .row(let server):
            delegate?.serversViewController(self, didSelect: server)
            
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
            
        case .section(_, let organization):
            guard let window = view.window, let organization = organization else {
                break
            }
            let alert = NSAlert()
            alert.alertStyle = .critical
            let name = organization.displayName ?? NSLocalizedString("this organization", comment: "")
            alert.messageText = NSLocalizedString("Remove \(name)?", comment: "")
            alert.informativeText = NSLocalizedString("You will no longer be able to connect to \(name).", comment: "")

            alert.addButton(withTitle: NSLocalizedString("Remove", comment: ""))
            alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
            alert.beginSheetModal(for: window) { response in
                switch response {
                case NSApplication.ModalResponse.alertFirstButtonReturn:
                    self.tableView.deselectRow(row)
                    self.delegate?.serversViewController(self, didDelete: organization)

                default:
                    break
                }
            }
            break
            
        case .row(let server):
            guard let window = view.window else {
                break
            }
            let alert = NSAlert()
            alert.alertStyle = .critical
            let name = server.displayName ?? NSLocalizedString("this server", comment: "")
            alert.messageText = NSLocalizedString("Remove \(name)?", comment: "")
            alert.informativeText = NSLocalizedString("You will no longer be able to connect to \(name).", comment: "")
           
            alert.addButton(withTitle: NSLocalizedString("Remove", comment: ""))
            alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
            alert.beginSheetModal(for: window) { response in
                switch response {
                case NSApplication.ModalResponse.alertFirstButtonReturn:
                    self.tableView.deselectRow(row)
                    self.delegate?.serversViewController(self, didDelete: server)

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
    
    fileprivate func updateInterface() {
        let row = tableView.selectedRow
        let providerSelected: Bool
        let canRemove: Bool
        
        if row < 0 {
            providerSelected = false
            canRemove = false
        } else {
            let tableRow = rows[row]
            
            switch tableRow {
                
            case .section(_, let organization):
                providerSelected = false
                canRemove = organization != nil
                
            case .row(let server):
                providerSelected = true
                
                let organization = (server.provider as? Organization)
                canRemove = organization == nil
                
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
        
        removeButton?.isHidden = !reachable
        removeButton?.isEnabled = canRemove && !busy
    }
}

// MARK: - TableView

extension ServersViewController {
    
    fileprivate enum TableRow {
        case section(String, Organization?)
        case row(Server)
    }
    
    fileprivate var rows: [TableRow] {
        var rows: [TableRow] = []
        guard started, let sections = fetchedResultsController.sections else {
            return rows
        }
        
        sections.forEach { section in
            let sectionName = section.name ?? "-"
            let organization = (section.objects.first?.provider as? Organization)
            
            rows.append(.section(sectionName, organization))
            section.objects.forEach { server in
                rows.append(.row(server))
            }
        }
        
        return rows
    }
}

extension ServersViewController: NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return rows.count
    }
}

extension ServersViewController: NSTableViewDelegate {
    
    @IBAction func toggleExpand(_ sender: NSButton) {
        guard let cellView = sender.superview else {
            return
        }
        
        let rowIndex = tableView.row(for: cellView)
        
        guard rows.indices.contains(rowIndex) else {
            return
        }
        
        let row = rows[rowIndex]
        switch row {
        case .row(let server):
            if server.isParent {
                server.isExpanded.toggle()
                try? server.managedObjectContext?.save()
                refresh(animated: true)
            }
        default:
            break
        }
    }
    
    private func configureSectionCellView(_ cellView: NSTableCellView, title: String) {
        cellView.textField?.stringValue = title
    }
    
    private func configureRowCellView(_ cellView: NSTableCellView, server: Server) {
        switch server.provider {
        case is Organization:
            cellView.imageView?.image = (!server.isParent || server.children?.count ?? 0 > 0) ? NSImage(named: "Secure Internet") :  NSImage(named: "Institute Access")
            cellView.imageView?.isHidden = false
            
        case is Custom:
            cellView.imageView?.image = NSImage(named: "Other")
            cellView.imageView?.isHidden = false
            
//        case is Local:
//            cellView.imageView?.image = NSImage(named: "Local")
//            cellView.imageView?.isHidden = false
            
        default:
            cellView.imageView?.image = nil
            cellView.imageView?.isHidden = true
            
        }
        
        cellView.textField?.stringValue = server.displayName ?? "-"
        
        let button = cellView.viewWithTag(3) as? NSButton
        button?.isHidden = !(server.isParent && server.children?.count ?? 0 > 0)
        button?.state = server.isExpanded ? .on : .off
        button?.target = self
        button?.action = #selector(toggleExpand(_:))
        
        cellView.constraints.first(where: { $0.identifier == "Indentation" })?.constant = server.isParent ? 8 : 28
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let tableRow = rows[row]
        
        switch tableRow {
            
        case .section(let title, _):
            let cellView = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "SectionCell"),
                                              owner: self)
            
            if let cellView = cellView as? NSTableCellView {
                configureSectionCellView(cellView, title: title)
            }
            
            return cellView
            
        case .row(let server):
            let cellView = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "ProfileCell"),
                                              owner: self)
            
            if let cellView = cellView as? NSTableCellView {
                configureRowCellView(cellView, server: server)
            }
            
            return cellView
        }
    }
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        let tableRow = rows[row]
        switch tableRow {
        case .section(_, let organization):
            return organization != nil
        case .row:
            return true
        }
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        updateInterface()
    }
    
    // Drag and drop currently not supported
//    func tableView(_ tableView: NSTableView,
//                   validateDrop info: NSDraggingInfo,
//                   proposedRow row: Int,
//                   proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
//
//        tableView.setDropRow(-1, dropOperation: .on)
//        return .copy
//    }
//
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
