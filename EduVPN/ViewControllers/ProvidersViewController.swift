//
//  ProvidersViewController.swift
//  eduVPN
//
//  Created by Jeroen Leenarts on 04-08-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

import CoreData
import NetworkExtension
import os.log
import UIKit

class ProviderTableViewCell: UITableViewCell {
    
    @IBOutlet private weak var providerImageView: UIImageView!
    @IBOutlet private weak var providerTitleLabel: UILabel!
    @IBOutlet private weak var statusImageView: UIImageView!
    
    func configure(with instance: Instance, and providerType: ProviderType, displayConnectedStatus: Bool) {
        let profiles = instance.apis?.flatMap { api -> Set<Profile> in
            return api.profiles
        } ?? []
        
        let configuredProfileId = UserDefaults.standard.configuredProfileId
        let configuredProfile = profiles.first { profile -> Bool in
            return profile.uuid?.uuidString == configuredProfileId
        }
        
        if displayConnectedStatus {
            statusImageView.isHidden = false
            accessoryType = .none
            
            switch configuredProfile?.vpnStatus ?? .invalid {
                
            case .connected:
                statusImageView.image = UIImage(named: "connected")
                
            case .connecting, .disconnecting, .reasserting:
                statusImageView.image = UIImage(named: "connecting")
                
            case .disconnected:
                statusImageView.image = UIImage(named: "disconnected")
                accessoryType = displayConnectedStatus ? .checkmark : .none
                
            case .invalid:
                statusImageView.image = nil
                
            @unknown default:
                fatalError()
                
            }
        } else {
            statusImageView.isHidden = true
            accessoryType = .none
        }
        
        if let logoString = instance.logos?.localizedValue, let logoUrl = URL(string: logoString) {
            ImageLoader.loadImage(logoUrl, target: providerImageView)
            providerImageView.isHidden = false
        } else {
            ImageLoader.cancelLoadImage(target: providerImageView)
            providerImageView.image = nil
            providerImageView.isHidden = true
        }
        
        providerTitleLabel?.text = instance.displayNames?.localizedValue ?? instance.baseUri
    }
}

extension ProviderTableViewCell: Identifiable {}

class ProvidersViewController: UITableViewController {
    
    weak var delegate: ProvidersViewControllerDelegate?
    
    @IBOutlet weak var addButton: UIBarButtonItem!
    @IBOutlet weak var settingsButton: UIBarButtonItem!
    
    var providerManagerCoordinator: TunnelProviderManagerCoordinator!
    
    var viewContext: NSManagedObjectContext!
    var selectingConfig: Bool = false
    
    var providerType: ProviderType = .unknown

    /// When `providerType == .unknown` the ProvidersViewController is supposed to display only instances that have been configured.
    var configuredForInstancesDisplay: Bool {
        return providerType == .unknown
    }
    
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

        if case .unknown = providerType {
            sortDescriptors.append(NSSortDescriptor(key: "lastAccessedTimeInterval", ascending: false))
        }

        sortDescriptors.append(NSSortDescriptor(key: "baseUri", ascending: true))
        fetchRequest.sortDescriptors = sortDescriptors
        
        let frc = FetchedResultsController<Instance>(fetchRequest: fetchRequest,
                                                     managedObjectContext: viewContext,
                                                     sectionNameKeyPath: Config.shared.discovery != nil ? "providerType": nil)
        frc.setDelegate(self.frcDelegate)
        
        return frc
    }()
    
    private lazy var frcDelegate: CoreDataFetchedResultsControllerDelegate<Instance> = { // swiftlint:disable:this weak_delegate
        return CoreDataFetchedResultsControllerDelegate<Instance>(tableView: self.tableView)
    }()
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        refresh()

        if configuredForInstancesDisplay && fetchedResultsController.count == 0 { // swiftlint:disable:this empty_count
            delegate?.noProfiles(providerTableViewController: self)
        }
    }
    
    @objc func refresh() {
        do {
            try fetchedResultsController.performFetch()
        } catch {
            os_log("Failed to fetch objects: %{public}@", log: Log.general, type: .error, error.localizedDescription)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.tableFooterView = UIView()

        if Config.shared.predefinedProvider != nil, configuredForInstancesDisplay {
            // There is a predefined provider. So do not allow adding.
            navigationItem.rightBarButtonItems = [settingsButton]
        } else if configuredForInstancesDisplay {
            navigationItem.rightBarButtonItems = [settingsButton, addButton]
        } else {
            navigationItem.rightBarButtonItems = []
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: Notification.Name.InstanceRefreshed, object: nil)
    }
    
    @IBAction func addProvider(_ sender: Any) {
        if Config.shared.predefinedProvider != nil {
            delegate?.addPredefinedProvider(providersViewController: self)
        } else {
            delegate?.addProvider(providersViewController: self, animated: true)
        }
    }
    
    @IBAction func settings(_ sender: Any) {
        delegate?.settings(providersViewController: self)
    }
}

// MARK: - TableView

extension ProvidersViewController {
    
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
        
        return providerType.title
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let providerCell = tableView.dequeueReusableCell(type: ProviderTableViewCell.self, for: indexPath)
        
        guard let sections = fetchedResultsController.sections else {
            fatalError("FetchedResultsController \(fetchedResultsController) should have sections, but found nil")
        }
        
        let section = sections[indexPath.section]
        let instance = section.objects[indexPath.row]
        
        providerCell.configure(with: instance, and: providerType, displayConnectedStatus: !selectingConfig)
        
        return providerCell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let sections = fetchedResultsController.sections else {
            fatalError("FetchedResultsController \(fetchedResultsController) should have sections, but found nil")
        }
        
        let section = sections[indexPath.section]
        let instance = section.objects[indexPath.row]
        
        delegate?.didSelect(instance: instance, providersViewController: self)
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return configuredForInstancesDisplay
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
            
            delegate?.delete(instance: instance)
        }
    }
}
