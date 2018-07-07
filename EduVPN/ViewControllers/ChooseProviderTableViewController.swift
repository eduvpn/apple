//
//  ChooseProviderTableViewController.swift
//  EduVPN
//
//  Created by Jeroen Leenarts on 04-08-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

import UIKit
import os.log

import CoreData
import BNRCoreDataStack
import AlamofireImage

class ProviderTableViewCell: UITableViewCell {

    @IBOutlet weak var providerImageView: UIImageView!
    @IBOutlet weak var providerTitleLabel: UILabel!
}

extension ProviderTableViewCell: Identifyable {}

protocol ChooseProviderTableViewControllerDelegate: class {
    func didSelect(instance: Instance, chooseProviderTableViewController: ChooseProviderTableViewController)
}

class ChooseProviderTableViewController: UITableViewController {
    weak var delegate: ChooseProviderTableViewControllerDelegate?

    var viewContext: NSManagedObjectContext!

    var providerType: ProviderType = .unknown

    private lazy var fetchedResultsController: FetchedResultsController<Instance> = {
        let fetchRequest = NSFetchRequest<Instance>()
        fetchRequest.entity = Instance.entity()
        fetchRequest.predicate = NSPredicate(format: "providerType == %@", providerType.rawValue)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "baseUri", ascending: true)]
        let frc = FetchedResultsController<Instance>(fetchRequest: fetchRequest,
                                                    managedObjectContext: viewContext,
                                                    sectionNameKeyPath: nil)
        frc.setDelegate(self.frcDelegate)
        return frc
    }()

    private lazy var frcDelegate: InstanceFetchedResultsControllerDelegate = { // swiftlint:disable:this weak_delegate
        return InstanceFetchedResultsControllerDelegate(tableView: self.tableView)
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        do {
            try fetchedResultsController.performFetch()
        } catch {
            os_log("Failed to fetch objects: %{public}@", log: Log.general, type: .error, [error])
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fetchedResultsController.sections?[section].objects.count ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let providerCell = tableView.dequeueReusableCell(type: ProviderTableViewCell.self, for: indexPath)

        guard let sections = fetchedResultsController.sections else {
            fatalError("FetchedResultsController \(fetchedResultsController) should have sections, but found nil")
        }

        let section = sections[indexPath.section]

        let instance = section.objects[indexPath.row]
        if let logoString = instance.logos?.localizedValue, let logoUrl = URL(string: logoString) {
            providerCell.providerImageView?.af_setImage(withURL: logoUrl)
        }
        providerCell.providerTitleLabel?.text = instance.displayNames?.localizedValue

        return providerCell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let sections = fetchedResultsController.sections else {
            fatalError("FetchedResultsController \(fetchedResultsController) should have sections, but found nil")
        }

        let section = sections[indexPath.section]
        let instance = section.objects[indexPath.row]

        delegate?.didSelect(instance: instance, chooseProviderTableViewController: self)
    }
}

extension ChooseProviderTableViewController: Identifyable {}

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
