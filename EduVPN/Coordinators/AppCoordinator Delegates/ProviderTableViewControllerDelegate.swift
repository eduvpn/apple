//
//  ProviderTableViewControllerDelegate.swift
//  eduVPN
//
//  Created by Aleksandr Poddubny on 30/05/2019.
//  Copyright © 2019 SURFNet. All rights reserved.
//

import Foundation
import PromiseKit

extension AppCoordinator: ProviderTableViewControllerDelegate {
    
    func addProvider(providerTableViewController: ProviderTableViewController) {
        addProvider()
    }
    
    func addPredefinedProvider(providerTableViewController: ProviderTableViewController) {
        if let providerUrl = Config.shared.predefinedProvider {
            _ = connect(url: providerUrl)
        }
    }
    
    func settings(providerTableViewController: ProviderTableViewController) {
        showSettings()
    }
    
    func didSelectOther(providerType: ProviderType) {
        showCustomProviderInPutViewController(for: providerType)
    }
    
    func didSelect(instance: Instance, providerTableViewController: ProviderTableViewController) {
        if providerTableViewController.providerType == .unknown {
            do {
                let count = try Profile.countInContext(persistentContainer.viewContext,
                                                       predicate: NSPredicate(format: "api.instance == %@", instance))
                
                if count > 1 {
                    showConnectionsTableViewController(for: instance)
                } else if let profile = instance.apis?.first?.profiles.first {
                    connect(profile: profile)
                }
            } catch {
                showError(error)
            }
        } else {
            // Move this to pull to refresh?
            refresh(instance: instance).recover { error in
                let error = error as NSError
                self.showError(error)
            }
        }
    }

    func delete(instance: Instance) {
        _ = Promise<Void>(resolver: { seal in
            persistentContainer.performBackgroundTask { context in
                if let backgroundProfile = context.object(with: instance.objectID) as? Instance {
                    backgroundProfile.apis?.forEach {
                        $0.certificateModel = nil
                        $0.authState = nil
                    }
                    
                    context.delete(backgroundProfile)
                }
                
                context.saveContext()
            }
            
            seal.fulfill(())
        })
    }
}
