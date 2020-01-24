//
//  ConnectionsTableViewControllerDelegate.swift
//  EduVPN
//
//  Created by Aleksandr Poddubny on 30/05/2019.
//  Copyright © 2020 SURFNet. All rights reserved.
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
            _ = tunnelProviderManagerCoordinator.disconnect()
                .recover { _ in self.tunnelProviderManagerCoordinator.configure(profile: profile) }
                .then { _ -> Promise<Void> in
                    self.providersViewController.tableView.reloadData()
                    return self.showConnectionViewController(for: profile)
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
