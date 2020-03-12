//
//  ConnectionsTableViewControllerDelegate.swift
//  EduVPN
//

import Foundation
import PromiseKit

extension ConnectionsTableViewController: Identifiable {}

extension AppCoordinator: ConnectionsTableViewControllerDelegate {
    
    func connectionsTableViewController(_ controller: ConnectionsTableViewController, refresh instance: Instance) -> Promise<Void> {
        return refresh(instance: instance)
    }
     
    func connectionsTableViewController(_ controller: ConnectionsTableViewController, connect profile: Profile) {
        connect(profile: profile)
    }
    
    func connectionsTableViewControllerNoProfiles(_ controller: ConnectionsTableViewController) {
        showNoProfilesAlert()
    }
    
    #if os(macOS)
    func connectionsTableViewControllerWantsToClose(_ controller: ConnectionsTableViewController) {
        mainWindowController.pop()
    }
    #endif
    
}
