//
//  EnterProviderURLViewController.swift
//  eduVPN
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
        
        doneButton.isEnabled = validURL != nil
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        view.window?.contentMaxSize = view.frame.size
        view.window?.contentMinSize = view.frame.size
        
        // Move cursor behind prefilled https://
        textField.currentEditor()?.selectedRange = NSRange(location: textField.stringValue.count, length: 0)
        textField.displayIfNeeded()
    }
    
    @IBAction func goBack(_ sender: Any) {
        guard let window = view.window else {
            return
        }
        window.sheetParent?.endSheet(window, returnCode: .cancel)
    }
    
    private var validURL: URL? {
        let string = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: string), let scheme = url.scheme, ["http", "https"].contains(scheme), url.host != nil {
            return url
        } else {
            return nil
        }
    }
    
    @IBAction func done(_ sender: Any) {
        textField.resignFirstResponder()
        textField.isEnabled = false
        doneButton.isEnabled = false
        
        guard let url = validURL, let window = view.window, url.host != nil else {
            guard let window = view.window else {
                return
            }
            let alert = NSAlert(customizedError: Error.invalidURL)
            alert?.beginSheetModal(for: window) { _ in
                self.textField.isEnabled = true
            }
            return
        }
        
        self.url = url
        
        window.sheetParent?.endSheet(window, returnCode: .OK)
    }
}

extension EnterProviderURLViewController: NSTextFieldDelegate {
    
    func controlTextDidChange(_ obj: Notification) {
        doneButton.isEnabled = validURL != nil
    }
}
