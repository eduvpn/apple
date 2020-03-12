//
//  CustomProviderInPutViewControllerDelegate.swift
//  eduVPN
//

import Foundation
import PromiseKit

extension AppCoordinator: CustomProviderInputViewControllerDelegate {
    
    func customProviderInputViewController(_ controller: CustomProviderInputViewController, connect url: URL) -> Promise<Void> {
        return connect(url: url)
    }
    
}
