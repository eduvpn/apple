//
//  AppCoordinator+Alert.swift
//  eduVPN
//
//  Created by Jeroen Leenarts on 09-06-18.
//  Copyright © 2018 SURFNet. All rights reserved.
//

import AppAuth
#if os(macOS)
import Cocoa
#endif
import os
#if os(iOS)
import UIKit
#endif

extension AppCoordinator {
    
    public func dueToUserCancellation(error: Error) -> Bool {
        let error = error as NSError
        return error.domain == OIDGeneralErrorDomain && (error.code == OIDErrorCode.programCanceledAuthorizationFlow.rawValue || error.code == OIDErrorCode.userCanceledAuthorizationFlow.rawValue)
    }
    
    public func underlyingError(for error: Error) -> Error? {
        return (error as NSError).userInfo[NSUnderlyingErrorKey] as? Error
    }
    
    public func showError(_ error: Error) {
        if dueToUserCancellation(error: error) {
            return
        }
        
        let displayedError = underlyingError(for: error) ?? error
        showAlert(title: NSLocalizedString("Error", comment: "Error alert title"), message: displayedError.localizedDescription)
        #if DEBUG
        print("error: \(error)")
        #endif
        os_log("Error occured %{public}@", log: Log.general, type: .error, error.localizedDescription)
    }
    
    func showNoAuthFlowAlert() {
        showAlert(title: NSLocalizedString("No auth flow available", comment: ""), message: NSLocalizedString("A call to `resumeAuthFlow` was called, but none available", comment: ""))
    }
    
    func showNoProfilesAlert() {
        showAlert(title: NSLocalizedString("No profiles available", comment: "No profiles available title"), message: NSLocalizedString("There are no profiles configured for you on the instance you selected.", comment: "No profiles available message"))
    }
    
    private func showAlert(title: String, message: String) {
        #if os(iOS)
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK button"), style: .default))
        
        let presentingViewController = navigationController.presentedViewController ?? navigationController
        presentingViewController.present(alert, animated: true)
        
        #elseif os(macOS)
        
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: NSLocalizedString("OK", comment: "OK button"))
        alert.beginSheetModal(for: windowController.window!)
        
        #endif
    }
}
