//
//  AppCoordinator+ViewControllers.swift
//  eduVPN
//
//  Created by Aleksandr Poddubny on 30/05/2019.
//  Copyright © 2019 SURFNet. All rights reserved.
//

import Foundation
import CoreData
import PromiseKit

extension AppCoordinator {
    
    internal func showSettings() {
        let settingsTableViewController = storyboard.instantiateViewController(type: SettingsTableViewController.self)
        settingsTableViewController.delegate = self
        navigationController.pushViewController(settingsTableViewController, animated: true)
    }
    
    internal func showConnectionsTableViewController(for instance: Instance) {
        let connectionsTableViewController = storyboard.instantiateViewController(type: ConnectionsTableViewController.self)
        connectionsTableViewController.delegate = self
        connectionsTableViewController.instance = instance
        connectionsTableViewController.viewContext = persistentContainer.viewContext
        navigationController.pushViewController(connectionsTableViewController, animated: true)
    }
    
    internal func showProfilesViewController() {
        let profilesViewController = storyboard.instantiateViewController(type: ProfilesViewController.self)
        
        let fetchRequest = NSFetchRequest<Profile>()
        fetchRequest.entity = Profile.entity()
        fetchRequest.predicate = NSPredicate(format: "api.instance.providerType == %@", ProviderType.secureInternet.rawValue)
        
        profilesViewController.delegate = self
        do {
            try profilesViewController.navigationItem.hidesBackButton = Profile.countInContext(persistentContainer.viewContext) == 0
            navigationController.pushViewController(profilesViewController, animated: true)
        } catch {
            showError(error)
        }
    }
    
    internal func showCustomProviderInPutViewController(for providerType: ProviderType) {
        let customProviderInputViewController = storyboard.instantiateViewController(type: CustomProviderInPutViewController.self)
        customProviderInputViewController.delegate = self
        navigationController.pushViewController(customProviderInputViewController, animated: true)
    }
    
    internal func showProviderTableViewController(for providerType: ProviderType) {
        let providerTableViewController = storyboard.instantiateViewController(type: ProviderTableViewController.self)
        providerTableViewController.providerType = providerType
        providerTableViewController.viewContext = persistentContainer.viewContext
        providerTableViewController.delegate = self
        providerTableViewController.selectingConfig = true
        navigationController.pushViewController(providerTableViewController, animated: true)
        
        providerTableViewController.providerType = providerType
        InstancesRepository.shared.loader.load(with: providerType)
    }
    
    internal func showConnectionViewController(for profile: Profile) -> Promise<Void> {
        let connectionViewController = storyboard.instantiateViewController(type: VPNConnectionViewController.self)
        connectionViewController.providerManagerCoordinator = tunnelProviderManagerCoordinator
        connectionViewController.delegate = self
        connectionViewController.profile = profile
    
        let navController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(type: UINavigationController.self)
        navController.viewControllers = [connectionViewController]
        let presentationPromise = Promise(resolver: { seal in
            self.navigationController.present(navController, animated: true, completion: { seal.resolve(nil) })
        })
        
        // We are configured and active.
        if profile.isActiveConfig && tunnelProviderManagerCoordinator.isActive {
            return presentationPromise
        }
        
        // We are configured and not active.
        if profile.isActiveConfig {
            return presentationPromise.then { self.tunnelProviderManagerCoordinator.connect() }
        }
        
        // We are unconfigured and not active.
        return presentationPromise
            .then { self.tunnelProviderManagerCoordinator.configure(profile: profile) }
            .then { self.tunnelProviderManagerCoordinator.connect() }
    }
    
    internal func showSettingsTableViewController() {
        let settingsTableViewController = storyboard.instantiateViewController(type: SettingsTableViewController.self)
        navigationController.pushViewController(settingsTableViewController, animated: true)
        settingsTableViewController.delegate = self
    }
}
