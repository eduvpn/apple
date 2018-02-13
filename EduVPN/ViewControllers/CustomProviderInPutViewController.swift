//
//  CustomProviderInPutViewController.swift
//  EduVPN
//
//  Created by Jeroen Leenarts on 29-10-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

import UIKit
import PromiseKit

protocol CustomProviderInPutViewControllerDelegate: class {
    @discardableResult func connect(url: URL) -> Promise<Void>
}

class CustomProviderInPutViewController: UIViewController {
    weak var delegate: CustomProviderInPutViewControllerDelegate?
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
        guard let url = urlFromInput() else { return }
        self.view.endEditing(false)
        delegate?.connect(url: url)
    }

    private func urlFromInput() -> URL? {
        guard let input = addressField.text, input.count > 0 else { return nil }
        let urlString = "https://\(input)"
        return URL(string: urlString)
    }
}

extension CustomProviderInPutViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard let url = urlFromInput() else { return true }
        self.view.endEditing(false)
        delegate?.connect(url: url)
        return true
    }
}

extension CustomProviderInPutViewController: KeyboardWrapperDelegate {
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

extension CustomProviderInPutViewController: Identifyable {}
