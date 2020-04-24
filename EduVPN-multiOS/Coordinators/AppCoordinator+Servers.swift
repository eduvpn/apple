//
//  ServersViewControllerDelegate.swift
//  eduVPN
//

import Foundation
import PromiseKit
import os.log

extension ServersViewController: Identifiable {}

extension AppCoordinator: ServersViewControllerDelegate {
    
    func serversViewControllerNoProfiles(_ controller: ServersViewController) {
        addProfilesWhenNoneAvailable()
    }

    func serversViewController(_ controller: ServersViewController, addProviderAnimated animated: Bool, allowClose: Bool) {
        #if os(iOS)
        addProvider(animated: animated, allowClose: allowClose)
        #elseif os(macOS)
        if config.apiDiscoveryEnabled ?? false {
            addProvider(animated: animated, allowClose: allowClose)
        } else {
            showCustomProviderInputViewController(for: .other, animated: animated)
        }
        #endif
    }
    
    func serversViewControllerAddPredefinedProvider(_ controller: ServersViewController) {
        if let providerUrl = config.predefinedProvider {
            _ = connect(url: providerUrl)
        }
    }
    
    #if os(iOS)
    func serversViewControllerShowSettings(_ controller: ServersViewController) {
        showSettings()
    }
    #endif
    
    func serversViewController(_ controller: ServersViewController, didSelect server: Server) {
        os_log("Did select server from provider: %{public}@ instance: %{public}@", log: Log.general, type: .info, "\(server.provider.debugDescription ?? "-")", "\(server)")
        
//        do {
//            persistentContainer.performBackgroundTask { (context) in
//                if let backgroundInstance = context.object(with: instance.objectID) as? Instance {
//                    let now = Date().timeIntervalSince1970
//                    backgroundInstance.lastAccessedTimeInterval = now
//                    context.saveContext()
//                }
//            }
//            let count = try Profile.countInContext(persistentContainer.viewContext,
//                                                   predicate: NSPredicate(format: "api.instance == %@", instance))
//
//            if count > 1 {
//                showConnectionsTableViewController(for: instance)
//            } else if let profile = instance.apis?.first?.profiles.first {
//                connect(profile: profile)
//            } else {
//                // Move this to pull to refresh?
//                refresh(instance: instance).then { _ -> Promise<Void> in
//                    return .value(())
//                }.recover { error in
//                    let error = error as NSError
//                    self.showError(error)
//                }
//            }
//        } catch {
//            showError(error)
//        }
        
    }
    
    func serversViewController(_ controller: ServersViewController, didDelete server: Server) {
        let context = server.managedObjectContext
        context?.delete(server)
        context?.saveContext()
    }
    
    func serversViewController(_ controller: ServersViewController, didDelete organization: Organization) {
        let context = organization.managedObjectContext
        context?.delete(organization)
        context?.saveContext()
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

}
