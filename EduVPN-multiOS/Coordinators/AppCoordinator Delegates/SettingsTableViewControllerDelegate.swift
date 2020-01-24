//
//  SettingsTableViewControllerDelegate.swift
//  eduVPN
//
//  Created by Aleksandr Poddubny on 30/05/2019.
//  Copyright © 2020 SURFNet. All rights reserved.
//

import Foundation

extension AppCoordinator: SettingsTableViewControllerDelegate {
    
    func reconnect() {
        _ = tunnelProviderManagerCoordinator.reconnect()
    }
    
    func readOnDemand() -> Bool {
        return tunnelProviderManagerCoordinator.currentManager?.isOnDemandEnabled ?? UserDefaults.standard.onDemand
    }
    
    func writeOnDemand(_ onDemand: Bool) {
        UserDefaults.standard.onDemand = onDemand
        tunnelProviderManagerCoordinator.currentManager?.isOnDemandEnabled = onDemand
        tunnelProviderManagerCoordinator.currentManager?.saveToPreferences(completionHandler: nil)
    }
}
