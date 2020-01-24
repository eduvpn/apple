//
//  CustomProviderInPutViewControllerDelegate.swift
//  eduVPN
//
//  Created by Aleksandr Poddubny on 30/05/2019.
//  Copyright © 2020 SURFNet. All rights reserved.
//

import Foundation
import PromiseKit

protocol CustomProviderInputViewControllerDelegate: class {
    @discardableResult func connect(url: URL) -> Promise<Void>
}

extension AppCoordinator: CustomProviderInputViewControllerDelegate {
    
    func connect(url: URL) -> Promise<Void> {
        return Promise<Instance>(resolver: { seal in
            persistentContainer.performBackgroundTask { context in
                let instanceGroupIdentifier = url.absoluteString
                let predicate = NSPredicate(format: "discoveryIdentifier == %@", instanceGroupIdentifier)
                let group = try! InstanceGroup.findFirstInContext(context, predicate: predicate) ?? InstanceGroup(context: context) //swiftlint:disable:this force_try
                
                let instance = Instance(context: context)
                instance.providerType = ProviderType.other.rawValue
                instance.baseUri = url.absoluteString
                
                let displayName = DisplayName(context: context)
                displayName.displayName = url.host
                instance.addToDisplayNames(displayName)
                instance.group = group
                
                do {
                    try context.save()
                } catch {
                    seal.reject(error)
                }
                
                seal.fulfill(instance)
            }
        }).then { instance -> Promise<Void> in
            let instance = self.persistentContainer.viewContext.object(with: instance.objectID) as! Instance //swiftlint:disable:this force_cast
            return self.refresh(instance: instance).then {_ -> Promise<Void> in
                #if os(iOS)
                self.popToRootViewController()
                #elseif os(macOS)
                self.popToRootViewController(animated: false, completionHandler: {
                    self.dismissViewController()
                })
                #endif

                return Promise.value(())
            }
        }.recover { error in
                let error = error as NSError
                self.showError(error)
        }
    }
}
