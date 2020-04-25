//
//  ConnectionsTableViewController.swift
//  eduVPN
//

import UIKit
import CoreData
import os.log
import PromiseKit

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
        
        connectTitleLabel?.text = profile.displayNames?.localizedValue ?? profile.profileId
        connectSubTitleLabel?.text = profile.providerDisplayString
        
        if let logo = profile.api?.instance?.logos?.localizedValue, let logoUri = URL(string: logo) {
            ImageLoader.loadImage(logoUri, target: connectImageView)
            connectImageView.isHidden = false
        } else {
            ImageLoader.cancelLoadImage(target: connectImageView)
            connectImageView.image = nil
            connectImageView.isHidden = true
        }
    }
}

extension ConnectTableViewCell: Identifiable {}

protocol ConnectionsTableViewControllerDelegate: class {
    func connectionsTableViewController(_ controller: ConnectionsTableViewController, refresh instance: Instance) -> Promise<Void>
    func connectionsTableViewController(_ controller: ConnectionsTableViewController, connect profile: Profile)
    func connectionsTableViewControllerNoProfiles(_ controller: ConnectionsTableViewController)
}

class ConnectionsTableViewController: UITableViewController {

    @IBOutlet weak var refreshButton: UIBarButtonItem!

    weak var delegate: ConnectionsTableViewControllerDelegate?
    
    var instance: Instance?
    var server: Server?

    var viewContext: NSManagedObjectContext!
    
    private lazy var fetchedResultsController: FetchedResultsController<Profile> = {
        let fetchRequest = NSFetchRequest<Profile>()
        fetchRequest.entity = Profile.entity()
        
        if let instance = instance {
            fetchRequest.predicate = NSPredicate(format: "api.instance == %@", instance)
        } else if let server = server {
            fetchRequest.predicate = NSPredicate(format: "server == %@", server)
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
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        refresh()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.tableFooterView = UIView()
        refresh()
        
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: Notification.Name.InstanceRefreshed, object: nil)
    }

    @IBAction func refreshAction(_ sender: Any) {
        guard let delegate = delegate, let instance = instance else { return }
        _ = firstly { () -> Promise<Void> in
            refreshButton.isEnabled = false
            return delegate.connectionsTableViewController(self, refresh: instance)
        }.ensure {
            self.refreshButton.isEnabled = true
        }
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
        
        delegate?.connectionsTableViewController(self, connect: profile)
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
