//
//  PasswordEntryViewController.swift
//  EduVPN

// Allows entry of password for OpenVPN configs that are configured to
// ask for password every time a connection is to be made.

import AppKit

protocol PasswordEntryViewControllerDelegate: AnyObject {
    func passwordEntryViewController(
        _ controller: PasswordEntryViewController,
        didSetCredentials credentials: Credentials)
    func passwordEntryViewControllerDidDisableVPN(
        _ controller: PasswordEntryViewController)
}

final class PasswordEntryViewController: ViewController, ParametrizedViewController {

    struct Parameters {
        let configName: String
        let userName: String
        let initialPassword: String
    }

    private var parameters: Parameters!

    weak var delegate: PasswordEntryViewControllerDelegate?
    var isPasswordChanged: Bool = false

    @IBOutlet weak var configNameLabel: NSTextField!
    @IBOutlet weak var userNameLabel: NSTextField!
    @IBOutlet weak var passwordTextField: NSSecureTextField!
    @IBOutlet weak var connectButton: NSButton!

    func initializeParameters(_ parameters: Parameters) {
        guard self.parameters == nil else {
            fatalError("Can't initialize parameters twice")
        }
        self.parameters = parameters
    }

    override func viewDidLoad() {
        setup(with: parameters)
    }

    private func setup(with parameters: Parameters) {
        configNameLabel.text = parameters.configName
        userNameLabel.text = parameters.userName
        passwordTextField.text = parameters.initialPassword
        connectButton.isEnabled = !parameters.initialPassword.isEmpty
    }

    private func connectWithEnteredPassword() {
        guard let password = passwordTextField.text, !password.isEmpty else {
            return
        }
        self.presentingViewController?.dismiss(self)
        let credentials = Credentials(
            userName: parameters.userName, password: password)
        delegate?.passwordEntryViewController(self, didSetCredentials: credentials)
    }

    private func disableVPN() {
        self.presentingViewController?.dismiss(self)
        delegate?.passwordEntryViewControllerDidDisableVPN(self)
    }

    @IBAction func connectClicked(_ sender: Any) {
        connectWithEnteredPassword()
    }

    @IBAction func disableVPNClicked(_ sender: Any) {
        disableVPN()
    }
}

extension PasswordEntryViewController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        isPasswordChanged = true
        connectButton.isEnabled = !(passwordTextField.text ?? "").isEmpty
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) { // Return
            connectWithEnteredPassword()
            return true
        } else if commandSelector == #selector(NSResponder.cancelOperation(_:)) { // Esc
            disableVPN()
            return true
        }
        return false
    }
}
