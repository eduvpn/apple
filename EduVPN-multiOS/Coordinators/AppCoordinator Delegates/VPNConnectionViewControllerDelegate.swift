//
//  VPNConnectionViewControllerDelegate.swift
//  eduVPN
//
//  Created by Aleksandr Poddubny on 30/05/2019.
//  Copyright © 2019 SURFNet. All rights reserved.
//

import Foundation
import PromiseKit

extension VPNConnectionViewController: Identifyable {}

protocol VPNConnectionViewControllerDelegate: class {
    @discardableResult func systemMessages(for profile: Profile) -> Promise<SystemMessages>
}

extension AppCoordinator: VPNConnectionViewControllerDelegate {

    func systemMessages(for profile: Profile) -> Promise<SystemMessages> {
        guard let api = profile.api else {
            precondition(false, "This should never happen")
            return Promise(error: AppCoordinatorError.apiMissing)
        }
        
        guard let dynamicApiProvider = DynamicApiProvider(api: api) else {
            return Promise(error: AppCoordinatorError.apiProviderCreateFailed)
        }
        
        return systemMessages(for: dynamicApiProvider)
    }
}
