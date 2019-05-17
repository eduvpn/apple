//
//  Enter2FAViewController.swift
//  eduVPN
//
//  Created by Johan Kool on 15/12/2017.
//  Copyright © 2017-2019 Commons Conservancy.
//

import Cocoa

protocol Enter2FAViewControllerDelegate: class {
    func enter2FA(controller: Enter2FAViewController, enteredTwoFactor: TwoFactor)
    func enter2FACancelled(controller: Enter2FAViewController)
}

class Enter2FAViewController: NSViewController {

    enum Error: Swift.Error, LocalizedError {
        case invalidToken
        
        var errorDescription: String? {
            switch self {
            case .invalidToken:
                return NSLocalizedString("Token is invalid", comment: "")
            }
        }
        
        var recoverySuggestion: String? {
            return NSLocalizedString("Enter a valid token.", comment: "")
        }
    }
    
    var initialTwoFactorType: TwoFactorType?
    
    weak var delegate: Enter2FAViewControllerDelegate?
    
    @IBOutlet var segmentedControl: NSSegmentedControl!
    @IBOutlet var textField: NSTextField!
    @IBOutlet var backButton: NSButton!
    @IBOutlet var doneButton: NSButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
                
        if let initialTwoFactorType = initialTwoFactorType {
            switch initialTwoFactorType {
             case .totp:
                segmentedControl.selectSegment(withTag: 0)
            case .yubico:
                segmentedControl.selectSegment(withTag: 1)
            }
        }
    }
    
    @IBAction func goBack(_ sender: Any) {
        delegate?.enter2FACancelled(controller: self)
    }
    
    private func validToken() -> TwoFactor? {
        let string = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        switch segmentedControl.selectedSegment {
        case 0:
            if string.count == 6, string.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted, options: []) == nil {
                return .totp(string)
            } else {
                return nil
            }
        case 1:
            if string.count == 44, string.rangeOfCharacter(from: CharacterSet.lowercaseLetters.inverted, options: []) == nil {
                return .yubico(string)
            } else {
                return nil
            }
        default:
            return nil
        }
    }
    
    @IBAction func typeChanged(_ sender: NSSegmentedControl) {
        doneButton.isEnabled = validToken() != nil
    }
    
    @IBAction func done(_ sender: Any) {
        segmentedControl.isEnabled = false
        textField.resignFirstResponder()
        textField.isEnabled = false
        doneButton.isEnabled = false
        
        guard let token = validToken() else {
            let alert = NSAlert(customizedError: Error.invalidToken)
            alert?.beginSheetModal(for: self.view.window!) { (_) in
                self.segmentedControl.isEnabled = true
                self.textField.isEnabled = true
            }
            return
        }
        
        delegate?.enter2FA(controller: self, enteredTwoFactor: token)
    }
}

extension Enter2FAViewController: NSTextFieldDelegate {
    
    func controlTextDidChange(_ obj: Notification) {
        doneButton.isEnabled = validToken() != nil
    }
    
}
