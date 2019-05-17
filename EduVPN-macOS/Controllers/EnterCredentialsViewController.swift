//
//  EnterCredentialsViewController.swift
//  eduVPN
//
//  Created by Johan Kool on 10/09/2018.
//  Copyright © 2017-2019 Commons Conservancy.
//

import Cocoa

class EnterCredentialsViewController: NSViewController {
    
    @IBOutlet var usernameField: NSTextField!
    @IBOutlet var passwordField: NSSecureTextField!
    @IBOutlet var cancelButton: NSButton!
    @IBOutlet var okButton: NSButton!
    @IBOutlet var saveInKeychainButton: NSButton!
    
    var credentials: (username: String, password: String, saveInKeychain: Bool)? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        okButton.isEnabled = validCredentials() != nil
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.contentMaxSize = view.frame.size
        view.window?.contentMinSize = view.frame.size
    }
    
    @IBAction func goBack(_ sender: Any) {
        view.window?.sheetParent?.endSheet(view.window!, returnCode: .cancel)
    }
    
    private func validCredentials() -> (username: String, password: String, saveInKeychain: Bool)? {
        let username = usernameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = passwordField.stringValue.trimmingCharacters(in: .newlines)
        let saveInKeychain = saveInKeychainButton.state == .on
        if !username.isEmpty && !password.isEmpty {
            return (username: username, password: password, saveInKeychain: saveInKeychain)
        } else {
            return nil
        }
    }
    
    @IBAction func done(_ sender: Any) {
        usernameField.resignFirstResponder()
        usernameField.isEnabled = false
        passwordField.resignFirstResponder()
        passwordField.isEnabled = false
        okButton.isEnabled = false
        
        credentials = validCredentials()
        
        guard let _ = credentials else {
            usernameField.isEnabled = true
            passwordField.isEnabled = true
            okButton.isEnabled = true
            return
        }
        
        view.window?.sheetParent?.endSheet(view.window!, returnCode: .OK)
    }
    
}

extension EnterCredentialsViewController: NSTextFieldDelegate {
    
    func controlTextDidChange(_ obj: Notification) {
        okButton.isEnabled = validCredentials() != nil
    }
    
}
