//
//  AppCoordinator+Alert.swift
//  eduVPN
//

import AppAuth
import PromiseKit
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
        switch error.domain {
        case OIDGeneralErrorDomain:
            switch error.code {
            case OIDErrorCode.programCanceledAuthorizationFlow.rawValue, OIDErrorCode.userCanceledAuthorizationFlow.rawValue:
                return true
            default:
                return false
            }
        default:
            if error.domain.hasSuffix("PromiseCancelledError") {
                switch error.code {
                case 1:
                    return true
                default:
                    return false
                }
            }
            return false
        }
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
        
        let presentingViewController = navigationController
        presentingViewController.present(alert, animated: true)
        
        #elseif os(macOS)

        if let window = windowController.window {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.addButton(withTitle: NSLocalizedString("OK", comment: "OK button"))
            alert.beginSheetModal(for: window)
        }
        
        #endif
    }

    func showActionSheet(title: String, message: String, confirmTitle: String, declineTitle: String) -> Promise<Bool> {
        #if os(iOS)
        return Promise<Bool>(resolver: { seal in
            let alert = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: confirmTitle, style: .default, handler: { (_) in
                seal.fulfill(true)
            }))
            alert.addAction(UIAlertAction(title: declineTitle, style: .cancel, handler: { (_) in
                seal.fulfill(false)
            }))

            let presentingViewController = navigationController.presentedViewController ?? navigationController
            presentingViewController.present(alert, animated: true)
        })
        #elseif os(macOS)
        return Promise<Bool>(resolver: { seal in
            if let window = windowController.window {
                let alert = NSAlert()
                alert.alertStyle = .warning
                alert.messageText = title
                alert.informativeText = message
                alert.addButton(withTitle: confirmTitle)
                alert.addButton(withTitle: declineTitle)
                alert.beginSheetModal(for: window) { response in
                    switch response {
                    case NSApplication.ModalResponse.alertFirstButtonReturn:
                        seal.fulfill(true)
                    case NSApplication.ModalResponse.cancel:
                        seal.fulfill(false)
                    default:
                        break
                    }
                }
            } else {
                seal.fulfill(true)
            }
        })
        #endif
    }
}
