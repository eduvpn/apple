//
//  CustomProviderInPutViewController.swift
//  eduVPN
//

import UIKit
import PromiseKit

protocol CustomProviderInputViewControllerDelegate: class {
    @discardableResult func customProviderInputViewController(_ controller: CustomProviderInputViewController, connect url: URL) -> Promise<Void>
}

class CustomProviderInputViewController: UIViewController {
    weak var delegate: CustomProviderInputViewControllerDelegate?
    @IBOutlet weak var bottomKeyboardConstraint: NSLayoutConstraint?
    @IBOutlet weak var connectButton: UIButton!
    @IBOutlet weak var addressField: UITextField!
    
    fileprivate var keyboardWrapper: KeyboardWrapper?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        keyboardWrapper = KeyboardWrapper(delegate: self)
        
        addressValueChanged(addressField)
    }
    
    @IBAction func addressValueChanged(_ sender: UITextField) {
        guard let url = urlFromInput() else {
            connectButton.isEnabled = false
            return
        }
        
        connectButton.isEnabled = url.scheme != nil && url.host != nil
    }
    
    @IBAction func connect(_ sender: UIButton) {
        connect()
    }

    private func urlFromInput() -> URL? {
        guard let input = addressField.text, !input.isEmpty else { return nil }
        let urlString = "https://\(input)"
        return URL(string: urlString)
    }
    
    private func connect() {
        guard let url = urlFromInput() else { return }
        self.view.endEditing(false)
        delegate?.customProviderInputViewController(self, connect: url)
    }
}

extension CustomProviderInputViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        connect()
        return true
    }
}

extension CustomProviderInputViewController: KeyboardWrapperDelegate {
    func keyboardWrapper(_ wrapper: KeyboardWrapper, didChangeKeyboardInfo info: KeyboardInfo) {
        if info.state == .willShow || info.state == .visible {
            bottomKeyboardConstraint?.constant = info.endFrame.size.height + 8.0
        } else {
            bottomKeyboardConstraint?.constant = 8.0
        }
        
        UIView.animate(withDuration: info.animationDuration, delay: 0.0, options: info.animationOptions, animations: { () -> Void in
            self.view.layoutIfNeeded()
        }, completion: nil)
    }
}

extension CustomProviderInputViewController: Identifiable {}
