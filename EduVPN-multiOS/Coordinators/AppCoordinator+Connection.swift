//
//  VPNConnectionViewControllerDelegate.swift
//  eduVPN
//

import Foundation
import NetworkExtension
import PromiseKit

extension VPNConnectionViewController: Identifiable {}

extension AppCoordinator: VPNConnectionViewControllerDelegate {

    func vpnConnectionViewController(_ controller: VPNConnectionViewController, systemMessagesForProfile profile: Profile) -> Promise<SystemMessages> {
        guard let api = profile.api else {
            precondition(false, "This should never happen")
            return Promise(error: AppCoordinatorError.apiMissing)
        }
        
        guard let dynamicApiProvider = DynamicApiProvider(api: api) else {
            return Promise(error: AppCoordinatorError.apiProviderCreateFailed)
        }
        
        return systemMessages(for: dynamicApiProvider)
    }
    
    func vpnConnectionViewControllerConfirmDisconnectWhileOnDemandEnabled(_ controller: VPNConnectionViewController) -> Promise<Bool> {
        // For now always say yes
        return Promise<Bool> { seal in
            seal.fulfill(true)
        }
        // Disabled dialog as it doesn't make sense if the setting can't be changed by the user
        //        return showActionSheet(title: NSLocalizedString("On Demand enabled", comment: ""),
        //                               message: NSLocalizedString("Are you sure you want to disconnect while “On Demand” is enabled?", comment: ""),
        //                               confirmTitle: NSLocalizedString("Disconnect", comment: ""),
        //                               declineTitle: NSLocalizedString("Cancel", comment: ""))
    }
    
    #if os(macOS)
    func vpnConnectionViewControllerWantsToClose(_ controller: VPNConnectionViewController) {
        mainWindowController.popToRoot()
    }
    #endif
}
