//
//  EnterProviderURLViewController.swift
//  eduVPN
//
//  Created by Johan Kool on 03/11/2017.
//  Copyright © 2017-2019 Commons Conservancy.
//

import Cocoa

class EnterProviderURLViewController: NSViewController {

    enum Error: Swift.Error, LocalizedError {
        case invalidURL
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return NSLocalizedString("URL is invalid", comment: "")
            }
        }
        
        var recoverySuggestion: String? {
            return NSLocalizedString("Enter a valid URL.", comment: "")
        }
    }
    
    @IBOutlet var textField: NSTextField!
    @IBOutlet var backButton: NSButton!
    @IBOutlet var doneButton: NSButton!
   
    var url: URL?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        doneButton.isEnabled = validURL() != nil
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.contentMaxSize = view.frame.size
        view.window?.contentMinSize = view.frame.size
    }
    
    @IBAction func goBack(_ sender: Any) {
        view.window?.sheetParent?.endSheet(view.window!, returnCode: .cancel)
    }
    
    private func validURL() -> URL? {
        let string = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: string), let scheme = url.scheme, ["http", "https"].contains(scheme), let _ = url.host {
            return url
        } else {
            return nil
        }
    }
    
    @IBAction func done(_ sender: Any) {
        textField.resignFirstResponder()
        textField.isEnabled = false
        doneButton.isEnabled = false
        
        guard let url = validURL(), let _ = url.host else {
            let alert = NSAlert(customizedError: Error.invalidURL)
            alert?.beginSheetModal(for: self.view.window!) { (_) in
                self.textField.isEnabled = true
            }
            return
        }
        
        self.url = url
        
        view.window?.sheetParent?.endSheet(view.window!, returnCode: .OK)
    }
    
}

extension EnterProviderURLViewController: NSTextFieldDelegate {
    
    func controlTextDidChange(_ obj: Notification) {
        doneButton.isEnabled = validURL() != nil
    }
    
}
