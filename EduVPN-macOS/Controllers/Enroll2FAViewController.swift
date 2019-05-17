//
//  Enroll2FAViewController.swift
//  eduVPN
//
//  Created by Johan Kool on 16/04/2018.
//  Copyright © 2017-2019 Commons Conservancy.
//

import Cocoa

protocol Enroll2FAViewControllerDelegate: class {
    func enroll2FA(controller: Enroll2FAViewController, didEnrollForType: TwoFactorType)
    func enroll2FACancelled(controller: Enroll2FAViewController)
}

class Enroll2FAViewController: NSViewController {

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
    
    weak var delegate: Enroll2FAViewControllerDelegate?
    var providerInfo: ProviderInfo!
    private var totpSecret: String!
    
    @IBOutlet var backButton: NSButton!
    @IBOutlet var segmentedControl: NSSegmentedControl!
    @IBOutlet var tabView: NSTabView!
    @IBOutlet var totpSecretField: NSTextField!
    @IBOutlet var qrImageView: NSImageView!
    @IBOutlet var totpResponseField: NSTextField!
    @IBOutlet var yubiTextField: NSTextField!
    @IBOutlet var doneButton: NSButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
                
        // TOTP preparations
        let twoFactorService = ServiceContainer.twoFactorService
        totpSecret = twoFactorService.generateSecret()
        let url = twoFactorService.generateURL(secret: totpSecret, provider: providerInfo)
        qrImageView.image = twoFactorService.generateQRCode(url: url)
        totpSecretField.stringValue = totpSecret
        
        totpResponseField.becomeFirstResponder()
    }
    
    @IBAction func goBack(_ sender: Any) {
        delegate?.enroll2FACancelled(controller: self)
    }
    
    private func validToken() -> TwoFactor? {
        switch segmentedControl.selectedSegment {
        case 0:
            let string = totpResponseField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if string.count == 6, string.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted, options: []) == nil {
                return .totp(string)
            } else {
                return nil
            }
        case 1:
            let string = yubiTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
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
        tabView.selectTabViewItem(at: sender.selectedSegment)
    }
    
    @IBAction func done(_ sender: Any) {
        segmentedControl.isEnabled = false
        totpResponseField.resignFirstResponder()
        yubiTextField.resignFirstResponder()
        totpResponseField.isEnabled = false
        yubiTextField.isEnabled = false
        doneButton.isEnabled = false
        
        guard let token = validToken() else {
            let alert = NSAlert(customizedError: Error.invalidToken)
            alert?.beginSheetModal(for: self.view.window!) { (_) in
                self.totpResponseField.isEnabled = true
                self.yubiTextField.isEnabled = true
            }
            return
        }
        
        let handler: (Result<Void>) -> () = { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.delegate?.enroll2FA(controller: self, didEnrollForType: token.twoFactorType)
                case .failure(let error):
                    let alert = NSAlert(customizedError: error)
                    alert?.beginSheetModal(for: self.view.window!) { (_) in
                        self.segmentedControl.isEnabled = true
                        self.totpResponseField.isEnabled = true
                        self.yubiTextField.isEnabled = true
                    }
                }
            }
        }
        
        switch token {
        case .totp(let otp):
            ServiceContainer.twoFactorService.enrollTotp(for: providerInfo, secret: totpSecret, otp: otp, handler: handler)
        case .yubico(let otp):
            ServiceContainer.twoFactorService.enrollYubico(for: providerInfo, otp: otp, handler: handler)
        }
        
    }
}

extension Enroll2FAViewController: NSTextFieldDelegate {
    
    func controlTextDidChange(_ obj: Notification) {
        doneButton.isEnabled = validToken() != nil
    }
    
}
