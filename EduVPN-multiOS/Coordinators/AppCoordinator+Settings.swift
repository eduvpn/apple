//
//  SettingsTableViewControllerDelegate.swift
//  eduVPN
//

import Foundation

extension AppCoordinator: SettingsTableViewControllerDelegate {
    
    func settingsTableViewControllerShouldReconnect(_ controller: SettingsTableViewController) {
        _ = tunnelProviderManagerCoordinator.reconnect()
    }

}
