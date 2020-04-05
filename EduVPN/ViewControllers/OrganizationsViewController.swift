//
//  OrganizationsViewController.swift
//  EduVPN
//
//  Created by Johan Kool on 02/04/2020.
//  Copyright © 2020 SURFNet. All rights reserved.
//

import UIKit
import os.log
import CoreData

protocol OrganizationsViewControllerDelegate: class {
    func organizationsViewController(_ controller: OrganizationsViewController, didSelect instance: Organization)
    func organizationsViewControllerShouldClose(_ controller: OrganizationsViewController)
    func organizationsViewControllerWantsToAddUrl(_ controller: OrganizationsViewController)
}

/// Used to display and search all available organizations and to select a specific organization to add.
class OrganizationsViewController: UITableViewController {
    
    weak var delegate: OrganizationsViewControllerDelegate?
    
    private var allowClose = true {
        didSet {
            guard isViewLoaded else {
                return
            }
//            backButton?.isHidden = !allowClose
        }
    }
    
    func allowClose(_ state: Bool) {
        self.allowClose = state
    }

    @IBOutlet weak var searchBar: UISearchBar?
        
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
        return CoreDataFetchedResultsControllerDelegate<Organization>(tableView: self.tableView)
    }()

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        refresh()
    }

    @objc func refresh() {
        do {
            if let query = searchBar?.text?.trimmingCharacters(in: .whitespacesAndNewlines), !query.isEmpty {
                fetchedResultsController.fetchRequest.predicate = NSPredicate(format: "displayName CONTAINS[cd] %@ OR keyword CONTAINS[cd] %@", query, query)
            } else {
                fetchedResultsController.fetchRequest.predicate = nil
            }
            try fetchedResultsController.performFetch()
        } catch {
            os_log("Failed to fetch objects: %{public}@", log: Log.general, type: .error, error.localizedDescription)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.tableFooterView = UIView()
    }

    @IBAction func enterProviderURL(_ sender: Any) {
        delegate?.organizationsViewControllerWantsToAddUrl(self)
    }

    @IBAction func search(_ sender: Any) {
        refresh()
    }
}

extension OrganizationsViewController {

    override func numberOfSections(in tableView: UITableView) -> Int {
        return fetchedResultsController.sections?.count ?? 0
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fetchedResultsController.sections?[section].objects.count ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let organizationCell = tableView.dequeueReusableCell(type: OrganizationTableViewCell.self, for: indexPath)

        guard let sections = fetchedResultsController.sections else {
            fatalError("FetchedResultsController \(fetchedResultsController) should have sections, but found nil")
        }

        let section = sections[indexPath.section]
        let organization = section.objects[indexPath.row]

        organizationCell.configure(with: organization)

        return organizationCell
    }
}

extension OrganizationsViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        refresh()
    }
}

class OrganizationTableViewCell: UITableViewCell {
    func configure(with organization: Organization) {
        textLabel?.text = organization.displayName
    }
}

extension OrganizationTableViewCell: Identifiable {}
