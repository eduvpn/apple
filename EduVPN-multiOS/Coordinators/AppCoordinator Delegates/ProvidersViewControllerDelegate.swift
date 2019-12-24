//
//  ProvidersViewControllerDelegate.swift
//  eduVPN
//
//  Created by Aleksandr Poddubny on 30/05/2019.
//  Copyright © 2019 SURFNet. All rights reserved.
//

import Foundation
import PromiseKit

import os.log

extension ProvidersViewController: Identifiable {}

protocol ProvidersViewControllerDelegate: class {
    func addProvider(providersViewController: ProvidersViewController, animated: Bool)
    func addPredefinedProvider(providersViewController: ProvidersViewController)
    func didSelect(instance: Instance, providersViewController: ProvidersViewController)
    func settings(providersViewController: ProvidersViewController)
    func delete(instance: Instance)
    #if os(macOS)
    func addCustomProviderWithUrl(_ url: URL)
    #endif
}

extension AppCoordinator: ProvidersViewControllerDelegate {
    func noProfiles(providerTableViewController: ProvidersViewControllerDelegate) {
        addProfilesWhenNoneAvailable()
    }

    func addProvider(providersViewController: ProvidersViewController, animated: Bool) {
        #if os(iOS)
        addProvider(animated: animated)
        #elseif os(macOS)
        if Config.shared.apiDiscoveryEnabled ?? false {
            addProvider(animated: animated)
        } else {
            showCustomProviderInputViewController(for: .other)
        }
        #endif
    }
    
    func addPredefinedProvider(providersViewController: ProvidersViewController) {
        if let providerUrl = Config.shared.predefinedProvider {
            _ = connect(url: providerUrl)
        }
    }
    
    func settings(providersViewController: ProvidersViewController) {
        showSettings()
    }
    
    func didSelectOther(providerType: ProviderType) {
        showCustomProviderInputViewController(for: providerType)
    }
    
    func didSelect(instance: Instance, providersViewController: ProvidersViewController) {
        os_log("Did select provider type: %{public}@ instance: %{public}@", log: Log.general, type: .info, "\(providersViewController.providerType)", "\(instance)")

        if providersViewController.providerType == .unknown {
            do {
                persistentContainer.performBackgroundTask { (context) in
                    if let backgroundInstance = context.object(with: instance.objectID) as? Instance {
                        let now = Date().timeIntervalSince1970
                        backgroundInstance.lastAccessedTimeInterval = now
                        context.saveContext()
                    }
                }
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
            refresh(instance: instance).then { _ -> Promise<Void> in
                self.popToRootViewController()
                return .value(())
            }.recover { error in
                let error = error as NSError
                self.showError(error)
            }
        }
    }
    
    func delete(instance: Instance) {
        // Check current profile UUID against profile UUIDs.
        if let configuredProfileId = UserDefaults.standard.configuredProfileId {
            let profiles = instance.apis?.flatMap { $0.profiles } ?? []
            if (profiles.compactMap { $0.uuid?.uuidString}.contains(configuredProfileId)) {
                _ = tunnelProviderManagerCoordinator.deleteConfiguration()
            }
        }

        var forced = false
        if let totalProfileCount = try? Profile.countInContext(persistentContainer.viewContext), let instanceProfileCount = instance.apis?.reduce(0, { (partial, api) -> Int in
            return partial + api.profiles.count
        }) {
            forced = totalProfileCount == instanceProfileCount
        }

        _ = Promise<Void>(resolver: { seal in
            persistentContainer.performBackgroundTask { context in
                if let backgroundInstance = context.object(with: instance.objectID) as? Instance {
                    backgroundInstance.apis?.forEach {
                        $0.certificateModel = nil
                        $0.authState = nil
                    }

                    context.delete(backgroundInstance)
                }
                
                context.saveContext()
            }
            
            seal.fulfill(())
        }).ensure {
            self.addProfilesWhenNoneAvailable(forced: forced)
        }
    }

    private func addProfilesWhenNoneAvailable(forced: Bool = false) {
        do {
            if try Profile.countInContext(persistentContainer.viewContext) == 0 || forced {
                // When running an authorization, do nothing. The user might already be adding a profile.
                // TODO fix this:if refreshingProfiles {
//                    return
//                }

                if let predefinedProvider = Config.shared.predefinedProvider {
                    _ = connect(url: predefinedProvider)
                } else {
                    addProvider()
                }
            }
        } catch {
            os_log("Failed to count Profile objects: %{public}@", log: Log.general, type: .error, error.localizedDescription)
        }
    }
    
    #if os(macOS)
    func addCustomProviderWithUrl(_ url: URL) {
        
    }
    #endif
}
