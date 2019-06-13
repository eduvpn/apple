//
//  ConnectionsTableViewControllerDelegate.swift
//  EduVPN
//
//  Created by Aleksandr Poddubny on 30/05/2019.
//  Copyright © 2019 SURFNet. All rights reserved.
//

import Foundation
import PromiseKit

protocol ConnectionsTableViewControllerDelegate: class {
    func connect(profile: Profile)
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
}
