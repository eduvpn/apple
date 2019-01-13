//
//  ConnectionsTableViewController.swift
//  EduVPN
//
//  Created by Jeroen Leenarts on 14-08-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

import UIKit
import CoreData
import os.log
import BNRCoreDataStack

class ConnectTableViewCell: UITableViewCell {

    @IBOutlet weak var connectImageView: UIImageView!
    @IBOutlet weak var connectTitleLabel: UILabel!
    @IBOutlet weak var connectSubTitleLabel: UILabel!
}

extension ConnectTableViewCell: Identifyable {}

protocol ConnectionsTableViewControllerDelegate: class {
    func addProvider(connectionsTableViewController: ConnectionsTableViewController)
    func addPredefinedProvider(connectionsTableViewController: ConnectionsTableViewController)
    func settings(connectionsTableViewController: ConnectionsTableViewController)
    func connect(profile: Profile, sourceView: UIView?)
    func delete(profile: Profile)
}

class ConnectionsTableViewController: UITableViewController {
    weak var delegate: ConnectionsTableViewControllerDelegate?
    
    @IBOutlet weak var addButton: UIBarButtonItem!
    @IBOutlet weak var settingsButton: UIBarButtonItem!
    
    weak var noConfigsButton: TableTextButton?
    
    var viewContext: NSManagedObjectContext! {
        willSet {
            if let context = viewContext {
                let notificationCenter = NotificationCenter.default
                notificationCenter.removeObserver(self, name: NSNotification.Name.NSManagedObjectContextObjectsDidChange, object: context)
            }
        }
        didSet {
            if let context = viewContext {
                let notificationCenter = NotificationCenter.default
                notificationCenter.addObserver(self, selector: #selector(managedObjectContextObjectsDidChange), name: NSNotification.Name.NSManagedObjectContextObjectsDidChange, object: context)
            }
        }
    }
    
    @objc
    func managedObjectContextObjectsDidChange(notification: NSNotification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + .nanoseconds(1)) { [weak self] in
            self?.checkButton()
        }
        
    }
    
    private func checkButton() {
        if self.fetchedResultsController.count == 0 && noConfigsButton == nil {
            let noConfigsButton = TableTextButton()
            noConfigsButton.title = NSLocalizedString("Add configuration", comment: "")
            noConfigsButton.autoresizingMask = [.flexibleHeight, .flexibleWidth]
            noConfigsButton.frame = tableView.bounds
            tableView.tableHeaderView = noConfigsButton
            self.noConfigsButton = noConfigsButton
        } else if self.fetchedResultsController.count > 0 {
            tableView.tableHeaderView = nil
        }
    }

    private lazy var fetchedResultsController: FetchedResultsController<Profile> = {
        let fetchRequest = NSFetchRequest<Profile>()
        fetchRequest.entity = Profile.entity()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "api.instance.providerType", ascending: true), NSSortDescriptor(key: "api.instance.baseUri", ascending: true), NSSortDescriptor(key: "profileId", ascending: true)]
        let frc = FetchedResultsController<Profile>(fetchRequest: fetchRequest,
                                                 managedObjectContext: viewContext,
                                                 sectionNameKeyPath: "api.instance.providerType")
        frc.setDelegate(self.frcDelegate)
        return frc
    }()

    private lazy var frcDelegate: ProfileFetchedResultsControllerDelegate = { // swiftlint:disable:this weak_delegate
        return ProfileFetchedResultsControllerDelegate(tableView: self.tableView)
    }()
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        checkButton()
    }
    
    @objc
    func tableTextButtonTapped() {
        self.delegate?.addProvider(connectionsTableViewController: self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let _ = Config.shared.predefinedProvider {
            // There is a predefined provider. So do not allow adding.
            navigationItem.rightBarButtonItems = [settingsButton]
        } else {
            navigationItem.rightBarButtonItems = [settingsButton, addButton]
        }
        
        tableView.tableFooterView = UIView()
        do {
            try fetchedResultsController.performFetch()
        } catch {
            os_log("Failed to fetch objects: %{public}@", log: Log.general, type: .error, error.localizedDescription)
        }
    }

    @IBAction func addProvider(_ sender: Any) {
        if let _ = Config.shared.predefinedProvider {
            delegate?.addPredefinedProvider(connectionsTableViewController: self)
        } else {
            delegate?.addProvider(connectionsTableViewController: self)
        }
    }

    @IBAction func settings(_ sender: Any) {
        delegate?.settings(connectionsTableViewController: self)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return fetchedResultsController.sections?.count ?? 0
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fetchedResultsController.sections?[section].objects.count ?? 0
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
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
        let cell = tableView.dequeueReusableCell(type: ConnectTableViewCell.self, for: indexPath)

        guard let sections = fetchedResultsController.sections else {
            fatalError("FetchedResultsController \(fetchedResultsController) should have sections, but found nil")
        }

        let section = sections[indexPath.section]
        let profile = section.objects[indexPath.row]
        

        if let currentProfileUuid = profile.uuid, currentProfileUuid.uuidString == UserDefaults.standard.configuredProfileId {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }
        
        cell.connectTitleLabel?.text = profile.profileId
        cell.connectSubTitleLabel?.text = profile.displayNames?.localizedValue ?? profile.api?.instance?.displayNames?.localizedValue ?? profile.api?.instance?.baseUri
        if let logo = profile.api?.instance?.logos?.localizedValue, let logoUri = URL(string: logo) {
            cell.connectImageView?.af_setImage(withURL: logoUri)
            cell.connectImageView.isHidden = false
        } else {
            cell.connectImageView.af_cancelImageRequest()
            cell.connectImageView.image = nil
            cell.connectImageView.isHidden = true
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let sections = fetchedResultsController.sections else {
            fatalError("FetchedResultsController \(fetchedResultsController) should have sections, but found nil")
        }

        let section = sections[indexPath.section]
        let profile = section.objects[indexPath.row]

        let sourceView = tableView.cellForRow(at: indexPath)

        delegate?.connect(profile: profile, sourceView: sourceView)

        tableView.deselectRow(at: indexPath, animated: true)
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {

            guard let sections = fetchedResultsController.sections else {
                fatalError("FetchedResultsController \(fetchedResultsController) should have sections, but found nil")
            }

            let section = sections[indexPath.section]
            let profile = section.objects[indexPath.row]

            delegate?.delete(profile: profile)
        }
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

class TableTextButton: UIView {
    let button: UIButton
    
    var title: String? {
        get {
            return button.title(for: .normal)
            
        }
        set(value) {
            button.setTitle(value, for: .normal)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("not been implemented")
    }
    
    init() {
        button = UIButton(type: .system)
        button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        super.init(frame: CGRect.zero)
        addSubview(button)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            NSLayoutConstraint(item: button, attribute: .width, relatedBy: .equal, toItem: button, attribute: .width, multiplier: 1, constant: 250)
            ])
        button.addTarget(nil, action: #selector(ConnectionsTableViewController.tableTextButtonTapped), for: .touchUpInside)
    }
}
