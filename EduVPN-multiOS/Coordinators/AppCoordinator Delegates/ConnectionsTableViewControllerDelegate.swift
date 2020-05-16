//
//  ConnectionsTableViewControllerDelegate.swift
//  EduVPN
//

import Foundation
import PromiseKit

extension ConnectionsTableViewController: Identifiable {}

protocol ConnectionsTableViewControllerDelegate: class {
    func refresh(instance: Instance) -> Promise<Void>
    func connect(profile: Profile)
    func noProfiles(providerTableViewController: ConnectionsTableViewController)
    
    #if os(macOS)
    func connectionsTableViewControllerWantsToClose(_ controller: ConnectionsTableViewController)
    #endif
}

extension AppCoordinator: ConnectionsTableViewControllerDelegate {
    
    func connect(profile: Profile) {
        if let currentProfileUuid = profile.uuid, currentProfileUuid.uuidString == UserDefaults.standard.configuredProfileId {
            _ = showConnectionViewController(for: profile)
        } else {
            _ = tunnelProviderManagerCoordinator.configure(profile: profile)
                .ensure {
                    self.providersViewController.tableView.reloadData()
                    _ = self.showConnectionViewController(for: profile)
                }
        }
    }
    
    func noProfiles(providerTableViewController: ConnectionsTableViewController) {
        showNoProfilesAlert()
    }
    
    #if os(macOS)
    func connectionsTableViewControllerWantsToClose(_ controller: ConnectionsTableViewController) {
        mainWindowController.pop()
    }
    #endif
    
}
