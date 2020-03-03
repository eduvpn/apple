//
//  TunnelProviderManagerCoordinatorDelegate.swift
//  eduVPN
//

import Foundation
import NetworkExtension
import PromiseKit

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
        NotificationCenter.default.post(name: Notification.Name.InstanceRefreshed, object: self)
    }
    
    func profileConfig(for profile: Profile) -> Promise<[String]> {
        #if os(iOS)
        showActivityIndicator(messageKey: "")
        #endif
        
        return fetchProfile(for: profile).ensure {
            #if os(iOS)
            _ = self.hideActivityIndicator()
            #endif
        }
    }
}
