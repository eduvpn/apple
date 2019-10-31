//
//  TunnelProviderManagerCoordinatorDelegate.swift
//  eduVPN
//
//  Created by Aleksandr Poddubny on 30/05/2019.
//  Copyright © 2019 SURFNet. All rights reserved.
//

import Foundation
import NetworkExtension
import PromiseKit

#if os(iOS)
import NVActivityIndicatorView
#endif

extension AppCoordinator: TunnelProviderManagerCoordinatorDelegate {
    
    func updateProfileStatus(with status: NEVPNStatus) {
        let context = persistentContainer.newBackgroundContext()
        context.performAndWait {
            let configuredProfileId = UserDefaults.standard.configuredProfileId
            try? Profile.allInContext(context).forEach {
                if configuredProfileId == $0.uuid?.uuidString {
                    $0.vpnStatus = status
                } else {
                    $0.vpnStatus = NEVPNStatus.invalid
                }
                
            }
            context.saveContextToStore()
        }
    }
    
    func profileConfig(for profile: Profile) -> Promise<URL> {
        #if os(iOS)
        let activityData = ActivityData()
        NVActivityIndicatorPresenter.sharedInstance.startAnimating(activityData, nil)
        #endif
        
        return fetchProfile(for: profile).ensure {
            #if os(iOS)
            NVActivityIndicatorPresenter.sharedInstance.stopAnimating(nil)
            #endif
        }
    }
}
