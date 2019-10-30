//
//  AppCoordinator+Mac.swift
//  EduVPN-macOS
//
//  Created by Aleksandr Poddubny on 02/06/2019.
//  Copyright © 2019 SURFNet. All rights reserved.
//

import Foundation

extension AppCoordinator {
    
    internal func chooseConfigFile(configFileURL: URL, recover: Bool = false) {
        // <UNCOMMENT>
        //        ServiceContainer.providerService.addProvider(configFileURL: configFileURL, recover: recover) { result in
        //            DispatchQueue.main.async {
        //                switch result {
        //                case .success:
        //                    self.mainWindowController?.dismiss()
        //                case .failure(let error):
        //                    let alert = NSAlert(customizedError: error)
        //                    if let error = error as? ProviderService.Error, !error.recoveryOptions.isEmpty {
        //                        error.recoveryOptions.forEach {
        //                            alert?.addButton(withTitle: $0)
        //                        }
        //                    }
        //                    
        //                    alert?.beginSheetModal(for: self.view.window!) { response in
        //                        switch response.rawValue {
        //                        case 1000:
        //                            self.chooseConfigFile(configFileURL: configFileURL, recover: true)
        //                        default:
        //                            break
        //                        }
        //                    }
        //                }
        //            }
        //        }
        // </UNCOMMENT>
    }
}
