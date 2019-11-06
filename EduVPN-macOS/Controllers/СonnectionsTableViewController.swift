//
//  СonnectionsTableViewController.swift
//  EduVPN-macOS
//
//  Created by Aleksandr Poddubny on 29/08/2019.
//  Copyright © 2019 SURFNet. All rights reserved.
//

import Cocoa
import CoreData
import os.log

class ConnectionsTableViewController: NSViewController {
    
    @IBOutlet var tableView: DeselectingTableView!
    @IBOutlet var backButton: NSButton!
    
    var profiles: [Profile] {
        guard let sections = fetchedResultsController.sections else {
            return []
        }
        
        return sections.map { $0.objects }.reduce([], +)
    }
    
    weak var delegate: ConnectionsTableViewControllerDelegate?
    
    var instance: Instance?
    
    var viewContext: NSManagedObjectContext!
    
    private lazy var fetchedResultsController: FetchedResultsController<Profile> = {
        let fetchRequest = NSFetchRequest<Profile>()
        fetchRequest.entity = Profile.entity()
        
        if let instance = instance {
            fetchRequest.predicate = NSPredicate(format: "api.instance == %@", instance)
        }
        
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "api.instance.providerType", ascending: true),
                                        NSSortDescriptor(key: "api.instance.baseUri", ascending: true),
                                        NSSortDescriptor(key: "profileId", ascending: true)]
        
        let frc = FetchedResultsController<Profile>(fetchRequest: fetchRequest,
                                                    managedObjectContext: viewContext)
        frc.setDelegate(self.frcDelegate)
        return frc
    }()
    
    private lazy var frcDelegate: CoreDataFetchedResultsControllerDelegate<Profile> = { // swiftlint:disable:this weak_delegate
        return CoreDataFetchedResultsControllerDelegate<Profile>(tableView: self.tableView)
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.deselectAll(nil)
        tableView.isEnabled = true
        
        refresh()

        if profiles.isEmpty {
            delegate?.noProfiles(providerTableViewController: self)
        }
    }

    override func viewWillAppear() {
        super.viewWillAppear()

    }
    
    @objc func refresh() {
        do {
            try fetchedResultsController.performFetch()
        } catch {
            os_log("Failed to fetch objects: %{public}@", log: Log.general, type: .error, error.localizedDescription)
        }
    }
    
    @IBAction func goBack(_ sender: Any) {
        mainWindowController?.pop()
    }
}

extension ConnectionsTableViewController: NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return profiles.count
    }
}

extension ConnectionsTableViewController: NSTableViewDelegate {
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let result = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "ProfileCell"), owner: self) as? NSTableCellView
        let profile = profiles[row]
        
        result?.textField?.stringValue = profile.displayNames?.localizedValue ?? profile.displayString ?? profile.profileId ?? ""
        return result
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        guard tableView.selectedRow >= 0 else {
            return
        }
        
        let profile = profiles[tableView.selectedRow]
        delegate?.connect(profile: profile)
        
        tableView.deselectRow(tableView.selectedRow)
    }
}
