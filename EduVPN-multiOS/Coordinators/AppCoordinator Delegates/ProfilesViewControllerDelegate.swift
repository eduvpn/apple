//
//  ProfilesViewControllerDelegate.swift
//  eduVPN
//
//  Created by Aleksandr Poddubny on 30/05/2019.
//  Copyright © 2019 SURFNet. All rights reserved.
//

import Foundation
import os.log

protocol ProfilesViewControllerDelegate: class {
    
    func profilesViewControllerDidSelectProviderType(profilesViewController: ProfilesViewController,
                                                     providerType: ProviderType)
    
    #if os(iOS)
    
    func settings(profilesViewController: ProfilesViewController)
    
    #elseif os(macOS)
    
    func profilesViewControllerWantsToAddUrl()
    func profilesViewControllerWantsChooseConfigFile()
    
    #endif
}

extension AppCoordinator: ProfilesViewControllerDelegate {
    
    func profilesViewControllerDidSelectProviderType(profilesViewController: ProfilesViewController,
                                                     providerType: ProviderType) {
    
        switch providerType {
            
        case .instituteAccess, .secureInternet:
            showProvidersViewController(for: providerType)
            
        case .other:
            showCustomProviderInPutViewController(for: providerType)
            
        case .unknown, .local:
            os_log("Unknown provider type chosen", log: Log.general, type: .error)
            
        }
    }
    
    #if os(iOS)
    
    func settings(profilesViewController: ProfilesViewController) {
        showSettings()
    }
    
    #elseif os(macOS)
    
    func profilesViewControllerWantsToAddUrl() {
        let enterProviderURLViewController = storyboard.instantiateController(withIdentifier: "EnterProviderURL")
            as! EnterProviderURLViewController
        
        let panel = NSPanel(contentViewController: enterProviderURLViewController)
        window?.beginSheet(panel) { response in
            switch response {
            case .OK:
                if let baseUrl = enterProviderURLViewController.url {
                    _ = self.connect(url: baseUrl)
                }
            default:
                break
            }
        }
    }
    
    func profilesViewControllerWantsChooseConfigFile() {
        guard let window = window else {
            return
        }
        
        NSOpenPanel().do {
            $0.canChooseFiles = true
            $0.canChooseDirectories = false
            $0.allowedFileTypes = ["ovpn"]
            $0.prompt = NSLocalizedString("Add", comment: "")
            
            let panel = $0
            $0.beginSheetModal(for: window) { response in
                if response == .OK, let url = panel.urls.first {
                    self.chooseConfigFile(configFileURL: url)
                }
            }
        }
    }
    
    #endif
}
