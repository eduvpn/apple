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
import Then

extension AppCoordinator {
    
    #if os(iOS)
    
    internal func pushViewController(_ viewController: UIViewController) {
        navigationController.pushViewController(viewController, animated: true)
    }
    
    internal func presentViewController(_ viewController: NSViewController) {
        present(viewController, animated: true)
    }
    
    #elseif os(macOS)
    
    internal func pushViewController(_ viewController: NSViewController) {
        (windowController as! MainWindowController).show(viewController: viewController, presentation: .push)
    }
    
    internal func presentViewController(_ viewController: NSViewController) {
        (windowController as! MainWindowController).show(viewController: viewController, presentation: .present)
    }
    
    #endif
    
    internal func showSettings() {
        #if os(iOS)
        let settingsVc = storyboard.instantiateViewController(type: SettingsTableViewController.self).with {
            $0.delegate = self
        }
        navigationController.pushViewController(settingsVc, animated: true)
        #elseif os(macOS)
        // TODO: Implement macOS
        abort()
        #endif
    }
    
    internal func showConnectionsTableViewController(for instance: Instance) {
        #if os(iOS)
        let connectionsVc = storyboard.instantiateViewController(type: ConnectionsTableViewController.self).with {
            $0.delegate = self
            $0.instance = instance
            $0.viewContext = persistentContainer.viewContext
        }
        
        navigationController.pushViewController(connectionsVc, animated: true)
        #elseif os(macOS)
        // TODO: Implement macOS
        abort()
        #endif
    }
    
    internal func showProfilesViewController() {
        let fetchRequest = NSFetchRequest<Profile>()
        fetchRequest.entity = Profile.entity()
        fetchRequest.predicate = NSPredicate(format: "api.instance.providerType == %@", ProviderType.secureInternet.rawValue)
        
        let profilesVc = storyboard.instantiateViewController(type: ProfilesViewController.self).with {
            $0.delegate = self
        }
        
        do {
            let allowClose = try Profile.countInContext(persistentContainer.viewContext) != 0
            profilesVc.allowClose(allowClose)
            
            #if os(iOS)
            pushViewController(profilesVc)
            #elseif os(macOS)
            presentViewController(profilesVc)
            #endif
        } catch {
            showError(error)
        }
    }
    
    internal func showCustomProviderInPutViewController(for providerType: ProviderType) {
        #if os(iOS)
        let customProviderInputVc = storyboard.instantiateViewController(type: CustomProviderInPutViewController.self).with {
            $0.delegate = self
        }
        navigationController.pushViewController(customProviderInputVc, animated: true)
        #elseif os(macOS)
        // TODO: Implement macOS
        abort()
        #endif
    }
    
    internal func showProvidersViewController(for providerType: ProviderType) {
        #if os(iOS)
        let providersVc = storyboard.instantiateViewController(type: ProvidersViewController.self)
        #elseif os(macOS)
        // Do separate instantiation with identifier
        // Because macOS reuses VC class, but uses two different layouts
        let providersVc = storyboard.instantiateController(withIdentifier: "ChooseProvider") as! ProvidersViewController
        #endif
        
        providersVc.do {
            $0.providerType = providerType
            $0.viewContext = persistentContainer.viewContext
            $0.delegate = self
            $0.selectingConfig = true
            $0.providerType = providerType
        }
        
        pushViewController(providersVc)
        
        // Required for startup safety purpose
        #if os(macOS)
        providersVc.start()
        #endif
        
        InstancesRepository.shared.loader.load(with: providerType)
    }
    
    internal func showConnectionViewController(for profile: Profile) -> Promise<Void> {
        #if os(iOS)
        let connectionVc = storyboard.instantiateViewController(type: VPNConnectionViewController.self).then {
            $0.providerManagerCoordinator = tunnelProviderManagerCoordinator
            $0.delegate = self
            $0.profile = profile
        }
    
        let nc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(type: UINavigationController.self).with {
            $0.viewControllers = [connectionVc]
        }
        
        let presentationPromise = Promise(resolver: { seal in
            self.navigationController.present(nc, animated: true, completion: { seal.resolve(nil) })
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
        #elseif os(macOS)
        // TODO: Implement macOS
        abort()
        #endif
    }
    
    internal func showSettingsTableViewController() {
        #if os(iOS)
        let settingsVc = storyboard.instantiateViewController(type: SettingsTableViewController.self).with {
            $0.delegate = self
        }
        navigationController.pushViewController(settingsVc, animated: true)
        #elseif os(macOS)
        // TODO: Implement macOS
        abort()
        #endif
    }
}
