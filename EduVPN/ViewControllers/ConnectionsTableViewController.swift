//
//  ConnectionsTableViewController.swift
//  eduVPN
//
//  Created by Jeroen Leenarts on 14-08-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

import UIKit
import CoreData
import os.log

class ConnectTableViewCell: UITableViewCell {
    @IBOutlet private weak var connectImageView: UIImageView!
    @IBOutlet private weak var connectTitleLabel: UILabel!
    @IBOutlet private weak var connectSubTitleLabel: UILabel!
    @IBOutlet private weak var statusImageView: UIImageView!

    func configure(with profile: Profile) {

        accessoryType = .none
        switch profile.vpnStatus {
        case .connected:
            statusImageView.image = UIImage(named: "connected")
        case .connecting, .disconnecting, .reasserting:
            statusImageView.image = UIImage(named: "connecting")
        case .disconnected:
            statusImageView.image = UIImage(named: "disconnected")
            accessoryType = .checkmark
        case .invalid:
            statusImageView.image = nil
        @unknown default:
            fatalError()
        }

        connectTitleLabel?.text = profile.displayNames?.localizedValue ?? profile.displayString ?? profile.profileId
        connectSubTitleLabel?.text = profile.displayString
        if let logo = profile.api?.instance?.logos?.localizedValue, let logoUri = URL(string: logo) {
            connectImageView?.af_setImage(withURL: logoUri)
            connectImageView.isHidden = false
        } else {
            connectImageView.af_cancelImageRequest()
            connectImageView.image = nil
            connectImageView.isHidden = true
        }

    }
}

extension ConnectTableViewCell: Identifyable {}

protocol ConnectionsTableViewControllerDelegate: class {
    func connect(profile: Profile)
}

class ConnectionsTableViewController: UITableViewController {
    weak var delegate: ConnectionsTableViewControllerDelegate?

    var instance: Instance?

    var viewContext: NSManagedObjectContext!

    private lazy var fetchedResultsController: FetchedResultsController<Profile> = {
        let fetchRequest = NSFetchRequest<Profile>()
        fetchRequest.entity = Profile.entity()
        if let instance = instance {
            fetchRequest.predicate = NSPredicate(format: "api.instance == %@", instance)
        }
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "api.instance.providerType", ascending: true), NSSortDescriptor(key: "api.instance.baseUri", ascending: true), NSSortDescriptor(key: "profileId", ascending: true)]
        let frc = FetchedResultsController<Profile>(fetchRequest: fetchRequest,
                                                 managedObjectContext: viewContext)
        frc.setDelegate(self.frcDelegate)
        return frc
    }()

    private lazy var frcDelegate: ProfileFetchedResultsControllerDelegate = { // swiftlint:disable:this weak_delegate
        return ProfileFetchedResultsControllerDelegate(tableView: self.tableView)
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.tableFooterView = UIView()
        refresh()
        NotificationCenter.default.addObserver(self, selector:#selector(refresh), name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    @objc func refresh() {
        do {
            try fetchedResultsController.performFetch()
        } catch {
            os_log("Failed to fetch objects: %{public}@", log: Log.general, type: .error, error.localizedDescription)
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return fetchedResultsController.sections?.count ?? 0
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fetchedResultsController.sections?[section].objects.count ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(type: ConnectTableViewCell.self, for: indexPath)

        guard let sections = fetchedResultsController.sections else {
            fatalError("FetchedResultsController \(fetchedResultsController) should have sections, but found nil")
        }

        let section = sections[indexPath.section]
        let profile = section.objects[indexPath.row]

        cell.configure(with: profile)

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let sections = fetchedResultsController.sections else {
            fatalError("FetchedResultsController \(fetchedResultsController) should have sections, but found nil")
        }

        let section = sections[indexPath.section]
        let profile = section.objects[indexPath.row]

        delegate?.connect(profile: profile)

        tableView.deselectRow(at: indexPath, animated: true)
    }
}

extension ConnectionsTableViewController: Identifyable {}

class ProfileFetchedResultsControllerDelegate: NSObject, FetchedResultsControllerDelegate {

    private weak var tableView: UITableView?

    // MARK: - Lifecycle
    init(tableView: UITableView) {
        self.tableView = tableView
    }

    func fetchedResultsControllerDidPerformFetch(_ controller: FetchedResultsController<Profile>) {
        tableView?.reloadData()
    }

    func fetchedResultsControllerWillChangeContent(_ controller: FetchedResultsController<Profile>) {
        tableView?.beginUpdates()
    }

    func fetchedResultsControllerDidChangeContent(_ controller: FetchedResultsController<Profile>) {
        tableView?.endUpdates()
    }

    func fetchedResultsController(_ controller: FetchedResultsController<Profile>, didChangeObject change: FetchedResultsObjectChange<Profile>) {
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

    func fetchedResultsController(_ controller: FetchedResultsController<Profile>, didChangeSection change: FetchedResultsSectionChange<Profile>) {
        guard let tableView = tableView else { return }
        switch change {
        case let .insert(_, index):
            tableView.insertSections(IndexSet(integer: index), with: .automatic)

        case let .delete(_, index):
            tableView.deleteSections(IndexSet(integer: index), with: .automatic)
        }
    }
}
