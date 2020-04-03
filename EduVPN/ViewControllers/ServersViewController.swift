//
//  ServersViewController.swift
//  EduVPN
//
//  Created by Johan Kool on 02/04/2020.
//  Copyright © 2020 SURFNet. All rights reserved.
//

import UIKit
import os.log
import CoreData

protocol ServersViewControllerDelegate: class {
    func serversViewControllerNoProfiles(_ controller: ServersViewController)
    func serversViewController(_ controller: ServersViewController, addProviderAnimated animated: Bool, allowClose: Bool)
    func serversViewControllerAddPredefinedProvider(_ controller: ServersViewController)
    func serversViewController(_ controller: ServersViewController, didSelect instance: Instance)
    func serversViewController(_ controller: ServersViewController, didDelete instance: Instance)
    func serversViewController(_ controller: ServersViewController, didDelete organization: Organization)
}

class ServersViewController: UITableViewController {

    weak var delegate: ServersViewControllerDelegate?

    @IBOutlet var unreachableLabel: UILabel?

    @IBOutlet var otherProviderButton: UIButton?

    var viewContext: NSManagedObjectContext!

    private var started = false

    private lazy var fetchedResultsController: FetchedResultsController<Instance> = {
        let fetchRequest = NSFetchRequest<Instance>()
        fetchRequest.entity = Instance.entity()

        // TODO: Use this too?  fetchRequest.predicate = NSPredicate(format: "apis.@count > 0 AND (SUBQUERY(apis, $y, (SUBQUERY($y.profiles, $z, $z != NIL).@count > 0)).@count > 0)")

        fetchRequest.predicate = NSPredicate(format: "provider != NIL AND (isParent == TRUE OR parent.isExpanded == TRUE)")

        var sortDescriptors = [NSSortDescriptor]() // TODO: This doesn't make much sense
        sortDescriptors.append(NSSortDescriptor(key: "provider.groupName", ascending: true))
        sortDescriptors.append(NSSortDescriptor(key: "parent.displayName", ascending: true))
        sortDescriptors.append(NSSortDescriptor(key: "sortName", ascending: true))
        sortDescriptors.append(NSSortDescriptor(key: "displayName", ascending: true))
        sortDescriptors.append(NSSortDescriptor(key: "baseUri", ascending: true))
        fetchRequest.sortDescriptors = sortDescriptors

        let frc = FetchedResultsController<Instance>(fetchRequest: fetchRequest,
                                                     managedObjectContext: viewContext,
                                                     sectionNameKeyPath: "provider.groupName")
        frc.setDelegate(self.frcDelegate)

        return frc
    }()

    private lazy var frcDelegate: CoreDataFetchedResultsControllerDelegate<Instance> = { // swiftlint:disable:this weak_delegate
        return CoreDataFetchedResultsControllerDelegate<Instance>(tableView: self.tableView)
    }()

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

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
        } catch {
            os_log("Failed to fetch objects: %{public}@", log: Log.general, type: .error, error.localizedDescription)
        }
    }
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    @IBAction func addOtherProvider(_ sender: Any) {
        delegate?.serversViewController(self, addProviderAnimated: true, allowClose: true)
    }

}

// MARK: - TableView

extension ServersViewController {

    override func numberOfSections(in tableView: UITableView) -> Int {
        return fetchedResultsController.sections?.count ?? 0
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fetchedResultsController.sections?[section].objects.count ?? 0
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let sections = fetchedResultsController.sections else {
            fatalError("FetchedResultsController \(fetchedResultsController) should have sections, but found nil")
        }
        let section = sections[section]
        return section.name
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let serverCell = tableView.dequeueReusableCell(type: ServerTableViewCell.self, for: indexPath)

        guard let sections = fetchedResultsController.sections else {
            fatalError("FetchedResultsController \(fetchedResultsController) should have sections, but found nil")
        }

        let section = sections[indexPath.section]
        let instance = section.objects[indexPath.row]

        serverCell.configure(with: instance)

        return serverCell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let sections = fetchedResultsController.sections else {
            fatalError("FetchedResultsController \(fetchedResultsController) should have sections, but found nil")
        }

        let section = sections[indexPath.section]
        let instance = section.objects[indexPath.row]

        delegate?.serversViewController(self, didSelect: instance)
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // TODO re-enable editing. But first need to make sure handling of instances and organizations is complete
        return false
    }

    override func tableView(_ tableView: UITableView,
                            commit editingStyle: UITableViewCell.EditingStyle,
                            forRowAt indexPath: IndexPath) {

        if editingStyle == .delete {
            guard let sections = fetchedResultsController.sections else {
                fatalError("FetchedResultsController \(fetchedResultsController) should have sections, but found nil")
            }

            let section = sections[indexPath.section]
            let instance = section.objects[indexPath.row]

            delegate?.serversViewController(self, didDelete: instance)
        }
    }

}

class ServerTableViewCell: UITableViewCell {
    func configure(with instance: Instance) {
        let providerType = ProviderType(rawValue: instance.providerType ?? "") ?? .unknown

        switch providerType {
        case .organization:
            imageView?.image = (!instance.isParent || instance.children?.count ?? 0 > 0) ? UIImage(named: "Secure Internet") :  UIImage(named: "Institute Access")
            imageView?.isHidden = false
        case .other:
            imageView?.image = UIImage.init(named: "Other")
            imageView?.isHidden = false
        case .local:
            imageView?.image = UIImage.init(named: "Local")
            imageView?.isHidden = false
        case .instituteAccess, .secureInternet, .unknown:
            imageView?.image = nil
            imageView?.isHidden = true
        }

        textLabel?.text = instance.displayName ?? "-"
    }
}

extension ServerTableViewCell: Identifiable {}
