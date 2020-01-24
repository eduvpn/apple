//
//  ProfilesViewControllerDelegate.swift
//  eduVPN
//
//  Created by Aleksandr Poddubny on 30/05/2019.
//  Copyright © 2020 SURFNet. All rights reserved.
//

import Foundation
import os.log
import PromiseKit

extension ProfilesViewController: Identifiable {}

protocol ProfilesViewControllerDelegate: class {
    
    func profilesViewControllerDidSelectProviderType(profilesViewController: ProfilesViewController,
                                                     providerType: ProviderType)
    
    #if os(iOS)
    
    func settings(profilesViewController: ProfilesViewController)
    
    #elseif os(macOS)
    
    func profilesViewControllerWantsToClose(_ controller: ProfilesViewController)
    func profilesViewControllerWantsToAddUrl(_ controller: ProfilesViewController)
    func profilesViewControllerWantsChooseConfigFile(_ controller: ProfilesViewController)
    
    #endif
}

extension AppCoordinator: ProfilesViewControllerDelegate {
    
    func profilesViewControllerDidSelectProviderType(profilesViewController: ProfilesViewController,
                                                     providerType: ProviderType) {
        
        switch providerType {
            
        case .instituteAccess, .secureInternet:
            showProvidersViewController(for: providerType)
            
        case .other:
            showCustomProviderInputViewController(for: providerType)
            
        case .unknown, .local:
            os_log("Unknown provider type chosen", log: Log.general, type: .error)
            
        }
    }
    
    #if os(iOS)
    
    func settings(profilesViewController: ProfilesViewController) {
        showSettings()
    }
    
    #elseif os(macOS)
    
    func profilesViewControllerWantsToClose(_ controller: ProfilesViewController) {
        mainWindowController.dismiss()
    }
    
    func profilesViewControllerWantsToAddUrl(_ controller: ProfilesViewController) {
        profilesViewControllerWantsToAddUrl()
    }
    
    func profilesViewControllerWantsToAddUrl() {
        guard let enterProviderURLViewController = storyboard.instantiateController(withIdentifier: "EnterProviderURL")
            as? EnterProviderURLViewController else {
                return
        }
        
        let panel = NSPanel(contentViewController: enterProviderURLViewController)
        window?.beginSheet(panel) { response in
            switch response {
            case .OK:
                if let baseUrl = enterProviderURLViewController.url {
                    _ = self.connect(url: baseUrl)
                        .then { _ -> Promise<Void> in
                            // Close profiles view once connected
                            return Promise(resolver: { seal in
                                self.dismissViewController()
                                seal.fulfill(())
                            })
                        }
                }
            default:
                break
            }
        }
    }
    
    func profilesViewControllerWantsChooseConfigFile(_ controller: ProfilesViewController) {
        guard let window = window else {
            return
        }
        
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedFileTypes = ["ovpn"]
        panel.prompt = NSLocalizedString("Add", comment: "")

        panel.beginSheetModal(for: window) { response in
            if response == .OK, let url = panel.urls.first {
                self.chooseConfigFile(configFileURL: url)
            }
        }
    }
    
    #endif
}
