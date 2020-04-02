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
                self.dismissViewController()
                return .value(())
            }.recover { error in
                let error = error as NSError
                self.showError(error)
            }
    }
    
    #if os(macOS)
    func organizationsViewControllerShouldClose(_ controller: OrganizationsViewController) {
        mainWindowController.dismiss()
    }
    
    func organizationsViewControllerWantsToAddUrl(_ controller: OrganizationsViewController) {
        userWantsToAddUrl()
    }
    #endif
}
