//
//  ProvidersViewControllerDelegate.swift
//  eduVPN
//

import Foundation
import PromiseKit
import os.log

extension ProvidersViewController: Identifiable {}

extension AppCoordinator: ProvidersViewControllerDelegate {
    
    func providersViewControllerNoProfiles(_ controller: ProvidersViewController) {
        addProfilesWhenNoneAvailable()
    }

    func providersViewController(_ controller: ProvidersViewController, addProviderAnimated animated: Bool, allowClose: Bool) {
        #if os(iOS)
        addProvider(animated: animated)
        #elseif os(macOS)
        if config.apiDiscoveryEnabled ?? false {
            addProvider(animated: animated, allowClose: allowClose)
        } else {
            showCustomProviderInputViewController(for: .other, animated: animated)
        }
        #endif
    }
    
    func providersViewControllerAddPredefinedProvider(_ controller: ProvidersViewController) {
        if let providerUrl = config.predefinedProvider {
            _ = connect(url: providerUrl)
        }
    }
    
    #if os(iOS)
    func providersViewControllerShowSettings(_ controller: ProvidersViewController) {
        showSettings()
    }
    #endif
    
    func didSelectOther(providerType: ProviderType) {
        showCustomProviderInputViewController(for: providerType, animated: true)
    }
    
    func providersViewController(_ controller: ProvidersViewController, didSelect instance: Instance) {
        os_log("Did select provider type: %{public}@ instance: %{public}@", log: Log.general, type: .info, "\(controller.providerType)", "\(instance)")

        if controller.configuredForInstancesDisplay {
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
                } else {
                    // Move this to pull to refresh?
                    refresh(instance: instance).then { _ -> Promise<Void> in
                        #if os(iOS)
                        self.popToRootViewController()
                        #elseif os(macOS)
                        // TODO: It is unclear to me why iOS pops to root here. For macOS dismiss seems wrong.
                        // self.dismissViewController()
                        #endif
                        return .value(())
                    }.recover { error in
                        let error = error as NSError
                        self.showError(error)
                    }
                }
            } catch {
                showError(error)
            }
        } else {
            // Move this to pull to refresh?
            refresh(instance: instance).then { _ -> Promise<Void> in
                #if os(iOS)
                self.popToRootViewController()
                #elseif os(macOS)
                // TODO: It is unclear to me why iOS pops to root here. For macOS dismiss seems wrong.
                // self.dismissViewController()
                #endif
                return .value(())
            }.recover { error in
                let error = error as NSError
                self.showError(error)
            }
        }
    }
    
    func providersViewController(_ controller: ProvidersViewController, didDelete instance: Instance) {
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
                if let predefinedProvider = config.predefinedProvider {
                    _ = connect(url: predefinedProvider)
                } else {
                    addProvider(allowClose: false)
                }
            }
        } catch {
            os_log("Failed to count Profile objects: %{public}@", log: Log.general, type: .error, error.localizedDescription)
        }
    }
    
    #if os(macOS)
    func providersViewControllerShouldClose(_ controller: ProvidersViewController) {
        mainWindowController.pop()
    }
    
    func providersViewController(_ controller: ProvidersViewController, addCustomProviderWithUrl url: URL) {
        
    }
    #endif
}
