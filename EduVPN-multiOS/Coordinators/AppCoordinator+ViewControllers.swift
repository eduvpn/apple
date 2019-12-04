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
    
    #if os(iOS)
    
    internal func pushViewController(_ viewController: UIViewController, animated: Bool = true) {
        navigationController.pushViewController(viewController, animated: animated)
    }
    
    internal func presentViewController(_ viewController: UIViewController,
                                        animated: Bool = true,
                                        completion: (() -> Void)? = nil) {
        navigationController.present(viewController, animated: animated, completion: completion)
    }
    
    internal func popToRootViewController() {
        navigationController.popToRootViewController(animated: true)
    }
    
    #elseif os(macOS)
    
    var mainWindowController: MainWindowController {
        return windowController as! MainWindowController //swiftlint:disable:this force_cast
    }
    
    internal func pushViewController(_ viewController: NSViewController,
                                             animated: Bool = true,
                                           completion: (() -> Void)? = nil) {
        mainWindowController.show(viewController: viewController,
                                  presentation: .push,
                                  animated: animated,
                                  completionHandler: completion)
    }
    
    internal func presentViewController(_ viewController: NSViewController,
                                        animated: Bool = true,
                                        completion: (() -> Void)? = nil) {
        
        mainWindowController.show(viewController: viewController,
                                  presentation: .present,
                                  animated: animated,
                                  completionHandler: completion)
    }
    
    internal func popToRootViewController(animated: Bool = true, completionHandler: (() -> Void)? = nil) {
        mainWindowController.popToRoot(animated: animated, completionHandler: completionHandler)
    }
    
    internal func dismissViewController() {
        if let lastOfLastViewController = mainWindowController.navigationStackStack.last?.last {
            mainWindowController.close(viewController: lastOfLastViewController)
        }
    }
    
    #endif
    
    internal func showSettings() {
        #if os(iOS)
        let settingsVc = storyboard.instantiateViewController(type: SettingsTableViewController.self)
        settingsVc.delegate = self
        navigationController.pushViewController(settingsVc, animated: true)
        #elseif os(macOS)
        // TODO: Implement macOS
        abort()
        #endif
    }
    
    internal func showConnectionsTableViewController(for instance: Instance) {
        let connectionsVc = storyboard.instantiateViewController(type: ConnectionsTableViewController.self)
        connectionsVc.delegate = self
        connectionsVc.instance = instance
        connectionsVc.viewContext = persistentContainer.viewContext
        #if os(iOS)
        navigationController.pushViewController(connectionsVc, animated: true)
        #elseif os(macOS)
        pushViewController(connectionsVc)
        #endif
    }
    
    internal func showProfilesViewController(animated: Bool = true) {
        let profilesVc = storyboard.instantiateViewController(type: ProfilesViewController.self)
        profilesVc.delegate = self

        do {
            let allowClose = try Profile.countInContext(persistentContainer.viewContext) != 0
            profilesVc.allowClose(allowClose)
            
            #if os(iOS)
            pushViewController(profilesVc, animated: animated)
            #elseif os(macOS)
            presentViewController(profilesVc, animated: animated)
            #endif
        } catch {
            showError(error)
        }
    }
    
    internal func showCustomProviderInputViewController(for providerType: ProviderType) {
        #if os(iOS)
        let customProviderInputVc = storyboard.instantiateViewController(type: CustomProviderInputViewController.self)
        customProviderInputVc.delegate = self

        navigationController.pushViewController(customProviderInputVc, animated: true)
        #elseif os(macOS)
        profilesViewControllerWantsToAddUrl()
        #endif
    }
    
    internal func showProvidersViewController(for providerType: ProviderType) {
        #if os(iOS)
        let providersVc = storyboard.instantiateViewController(type: ProvidersViewController.self)
        #elseif os(macOS)
        // Do separate instantiation with identifier
        // Because macOS reuses VC class, but uses two different layouts
        guard let providersVc = storyboard.instantiateController(withIdentifier: "ChooseProvider") as? ProvidersViewController else {
            return
        }
        #endif
        
        providersVc.providerType = providerType
        providersVc.viewContext = persistentContainer.viewContext
        providersVc.delegate = self
        providersVc.selectingConfig = true
        providersVc.providerType = providerType

        pushViewController(providersVc)
        
        // Required for startup safety purpose
        #if os(macOS)
        providersVc.start()
        #endif
        
        InstancesRepository.shared.loader.load(with: providerType)
    }
    
    internal func showConnectionViewController(for profile: Profile) -> Promise<Void> {
        let connectionVc = storyboard.instantiateViewController(type: VPNConnectionViewController.self)
        connectionVc.providerManagerCoordinator = tunnelProviderManagerCoordinator
        connectionVc.delegate = self
        connectionVc.profile = profile

        #if os(iOS)
        let navigationController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(type: UINavigationController.self)
        navigationController.viewControllers = [connectionVc]
        navigationController.modalPresentationStyle = .pageSheet
        #endif
        
        let presentationPromise = Promise<Void>(resolver: { seal in
            #if os(iOS)
            self.presentViewController(navigationController, animated: true, completion: { seal.resolve(nil) })
            #elseif os(macOS)
            self.pushViewController(connectionVc, animated: true, completion: { seal.resolve(nil) })
            #endif
        })
        
        // We are configured and active.
        if profile.isActiveConfig && tunnelProviderManagerCoordinator.isActive {
            return presentationPromise
        }
        
        // We are configured and not active / We are unconfigured and not active.
        return presentationPromise
            .then { self.tunnelProviderManagerCoordinator.configure(profile: profile) }
            .then { self.tunnelProviderManagerCoordinator.connect() }
    }

}
