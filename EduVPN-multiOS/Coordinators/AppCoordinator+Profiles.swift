//
//  ProfilesViewControllerDelegate.swift
//  eduVPN
//

import Foundation
import os.log
import PromiseKit

extension ProfilesViewController: Identifiable {}

extension AppCoordinator: ProfilesViewControllerDelegate {
    
    func profilesViewControllerDidSelectProviderType(_ controller: ProfilesViewController, providerType: ProviderType) {
        switch providerType {
            
        case .instituteAccess, .secureInternet:
            showProvidersViewController(for: providerType, animated: true)
            
        case .other:
            showCustomProviderInputViewController(for: providerType, animated: true)
            
        case .unknown, .local, .organization:
            os_log("Unknown provider type chosen", log: Log.general, type: .error)
            
        }
    }
    
    #if os(iOS)
    
    func profilesViewControllerShowSettings(_ controller: ProfilesViewController) {
        showSettings()
    }
    
    #elseif os(macOS)
    
    func profilesViewControllerWantsToClose(_ controller: ProfilesViewController) {
        mainWindowController.dismiss()
    }
    
    func profilesViewControllerWantsToAddUrl(_ controller: ProfilesViewController) {
        userWantsToAddUrl()
    }
    
    func userWantsToAddUrl() {
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
    
    func profilesViewControllerApiDiscoveryEnabled(_ controller: ProfilesViewController) -> Bool {
        return config.apiDiscoveryEnabled ?? false
    }
    #endif
}
