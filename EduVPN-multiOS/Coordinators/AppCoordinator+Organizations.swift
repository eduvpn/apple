//
//  OrganizationsViewControllerDelegate.swift
//  eduVPN
//

import Foundation
import PromiseKit
import os.log

extension OrganizationsViewController: Identifiable {}

extension AppCoordinator: OrganizationsViewControllerDelegate {
    
    func organizationsViewController(_ controller: OrganizationsViewController, didSelect organization: Organization) {
        os_log("Did select organization: %{public}@", log: Log.general, type: .info, "\(organization.displayName ?? "")")

        serversRepository.loader.load(with: organization)
            .then { _ -> Promise<Void> in
                #if os(iOS)
                controller.dismiss(animated: true, completion: nil)
                #elseif os(macOS)
                self.dismissViewController()
                #endif
                return .value(())
            }.recover { error in
                let error = error as NSError
                self.showError(error)
            }
    }
    
    func organizationsViewControllerShouldClose(_ controller: OrganizationsViewController) {
        #if os(macOS)
        mainWindowController.dismiss()
        #endif
    }
    
    func organizationsViewControllerWantsToAddUrl(_ controller: OrganizationsViewController) {
        #if os(macOS)
        userWantsToAddUrl()
        #endif
    }
    
}
