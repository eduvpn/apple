//
//  ProviderTableViewController.swift
//  eduVPN
//
//  Created by Jeroen Leenarts on 04-08-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

import UIKit
import os.log

import NetworkExtension

import CoreData
import BNRCoreDataStack
import AlamofireImage

class ProviderTableViewCell: UITableViewCell {

    @IBOutlet weak var providerImageView: UIImageView!
    @IBOutlet weak var providerTitleLabel: UILabel!
}

extension ProviderTableViewCell: Identifyable {}

protocol ProviderTableViewControllerDelegate: class {
    func addProvider(providerTableViewController: ProviderTableViewController)
    func addPredefinedProvider(providerTableViewController: ProviderTableViewController)
    func didSelect(instance: Instance, providerTableViewController: ProviderTableViewController)
    func settings(providerTableViewController: ProviderTableViewController)
    func delete(instance: Instance)
}

class ProviderTableViewController: UITableViewController {
    weak var delegate: ProviderTableViewControllerDelegate?

    @IBOutlet weak var addButton: UIBarButtonItem!
    @IBOutlet weak var settingsButton: UIBarButtonItem!

    var providerManagerCoordinator: TunnelProviderManagerCoordinator!

    var viewContext: NSManagedObjectContext!

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

    private lazy var frcDelegate: InstanceFetchedResultsControllerDelegate = { // swiftlint:disable:this weak_delegate
        return InstanceFetchedResultsControllerDelegate(tableView: self.tableView)
    }()

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        refresh()
    }

    func refresh() {
        do {
            try fetchedResultsController.performFetch()
        } catch {
            os_log("Failed to fetch objects: %{public}@", log: Log.general, type: .error, error.localizedDescription)
        }
    }

    override func viewDidLoad() {
        tableView.tableFooterView = UIView()

        super.viewDidLoad()

        if Config.shared.predefinedProvider != nil, providerType == .unknown {
            // There is a predefined provider. So do not allow adding.
            navigationItem.rightBarButtonItems = [settingsButton]
        } else if providerType == .unknown {
            navigationItem.rightBarButtonItems = [settingsButton, addButton]
        } else {
            navigationItem.rightBarButtonItems = []
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return fetchedResultsController.sections?.count ?? 0
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fetchedResultsController.sections?[section].objects.count ?? 0
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard Config.shared.discovery != nil else {
            return nil
        }

        let providerType: ProviderType

        if let sectionName = fetchedResultsController.sections?[section].name {
            providerType = ProviderType(rawValue: sectionName) ?? .unknown
        } else {
            providerType = .unknown
        }

        switch providerType {
        case .secureInternet:
            return NSLocalizedString("Secure Internet", comment: "")
        case .instituteAccess:
            return NSLocalizedString("Institute access", comment: "")
        case .other:
            return NSLocalizedString("Other", comment: "")
        case .unknown:
            return "."
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let providerCell = tableView.dequeueReusableCell(type: ProviderTableViewCell.self, for: indexPath)

        guard let sections = fetchedResultsController.sections else {
            fatalError("FetchedResultsController \(fetchedResultsController) should have sections, but found nil")
        }

        let section = sections[indexPath.section]
        let instance = section.objects[indexPath.row]

        let profileUuids = instance.apis?.flatMap({ (api) -> [String] in
            return api.profiles.compactMap { $0.uuid?.uuidString }
        }) ?? []

        if let configuredProfileId = UserDefaults.standard.configuredProfileId, providerType == .unknown, profileUuids.contains(configuredProfileId) {
            providerCell.accessoryType = .checkmark
        } else {
            providerCell.accessoryType = .none
        }
        if let logoString = instance.logos?.localizedValue, let logoUrl = URL(string: logoString) {
            providerCell.providerImageView?.af_setImage(withURL: logoUrl)
            providerCell.providerImageView.isHidden = false
        } else {
            providerCell.providerImageView.af_cancelImageRequest()
            providerCell.providerImageView.image = nil
            providerCell.providerImageView.isHidden = true
        }
        providerCell.providerTitleLabel?.text = instance.displayNames?.localizedValue ?? instance.baseUri

        return providerCell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let sections = fetchedResultsController.sections else {
            fatalError("FetchedResultsController \(fetchedResultsController) should have sections, but found nil")
        }

        let section = sections[indexPath.section]
        let instance = section.objects[indexPath.row]

        delegate?.didSelect(instance: instance, providerTableViewController: self)
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return providerType == .unknown
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {

            guard let sections = fetchedResultsController.sections else {
                fatalError("FetchedResultsController \(fetchedResultsController) should have sections, but found nil")
            }

            let section = sections[indexPath.section]
            let instance = section.objects[indexPath.row]

            delegate?.delete(instance: instance)
        }
    }

    @IBAction func addProvider(_ sender: Any) {
        if Config.shared.predefinedProvider != nil {
            delegate?.addPredefinedProvider(providerTableViewController: self)
        } else {
            delegate?.addProvider(providerTableViewController: self)
        }
    }

    @IBAction func settings(_ sender: Any) {
        delegate?.settings(providerTableViewController: self)
    }

}

extension ProviderTableViewController: Identifyable {}

class InstanceFetchedResultsControllerDelegate: NSObject, FetchedResultsControllerDelegate {

    private weak var tableView: UITableView?

    // MARK: - Lifecycle
    init(tableView: UITableView) {
        self.tableView = tableView
    }

    func fetchedResultsControllerDidPerformFetch(_ controller: FetchedResultsController<Instance>) {
        tableView?.reloadData()
    }

    func fetchedResultsControllerWillChangeContent(_ controller: FetchedResultsController<Instance>) {
        tableView?.beginUpdates()
    }

    func fetchedResultsControllerDidChangeContent(_ controller: FetchedResultsController<Instance>) {
        tableView?.endUpdates()
    }

    func fetchedResultsController(_ controller: FetchedResultsController<Instance>, didChangeObject change: FetchedResultsObjectChange<Instance>) {
        guard let tableView = tableView else { return }
        switch change {
        case let .insert(_, indexPath):
            tableView.insertRows(at: [indexPath], with: .automatic)

        case let .delete(_, indexPath):
            tableView.deleteRows(at: [indexPath], with: .automatic)

        case let .move(_, fromIndexPath, toIndexPath):
            tableView.moveRow(at: fromIndexPath, to: toIndexPath)

        case let .update(_, indexPath):
            tableView.reloadRows(at: [indexPath], with: .automatic)
        }
    }

    func fetchedResultsController(_ controller: FetchedResultsController<Instance>, didChangeSection change: FetchedResultsSectionChange<Instance>) {
        guard let tableView = tableView else { return }
        switch change {
        case let .insert(_, index):
            tableView.insertSections(IndexSet(integer: index), with: .automatic)

        case let .delete(_, index):
            tableView.deleteSections(IndexSet(integer: index), with: .automatic)
        }
    }
}
