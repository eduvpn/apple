//
//  ProfilesViewControllerDelegate.swift
//  eduVPN
//
//  Created by Aleksandr Poddubny on 30/05/2019.
//  Copyright © 2019 SURFNet. All rights reserved.
//

import Foundation
import os.log

extension AppCoordinator: ProfilesViewControllerDelegate {
    
    func settings(profilesViewController: ProfilesViewController) {
        showSettings()
    }
    
    func profilesViewControllerDidSelectProviderType(profilesViewController: ProfilesViewController,
                                                     providerType: ProviderType) {
    
        switch providerType {
            
        case .instituteAccess, .secureInternet:
            showProvidersViewController(for: providerType)
            
        case .other:
            showCustomProviderInPutViewController(for: providerType)
            
        case .unknown:
            os_log("Unknown provider type chosen", log: Log.general, type: .error)
            
        }
    }
}
