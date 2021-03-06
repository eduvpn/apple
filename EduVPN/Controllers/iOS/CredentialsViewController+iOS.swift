//
//  CredentialsViewController+iOS.swift
//  EduVPN

import UIKit

extension CredentialsViewController {
    func setup(with credentials: OpenVPNConfigCredentials?) {
        cancelButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped(_:)))
        saveButtonItem = UIBarButtonItem(
            barButtonSystemItem: .save, target: self, action: #selector(saveTapped(_:)))

        navigationItem.leftBarButtonItem = cancelButtonItem
        navigationItem.rightBarButtonItem = saveButtonItem

        if let credentials = credentials {
            userNameTextField.text = credentials.userName
            if case .useSavedPassword(let password) = credentials.passwordStrategy {
                passwordTextField.text = password
            }
        }
        updateControlsState(with: credentials)

        if #available(iOS 13.0, *) {
            isModalInPresentation = true // Prevent dismissing by swiping down
        }

        NotificationCenter.default.addObserver(
            self, selector: #selector(updateSaveButtonState(_:)),
            name: UITextField.textDidChangeNotification, object: userNameTextField)
        NotificationCenter.default.addObserver(
            self, selector: #selector(updateSaveButtonState(_:)),
            name: UITextField.textDidChangeNotification, object: passwordTextField)
    }

    private func updateControlsState(with credentials: OpenVPNConfigCredentials?) {
        if let credentials = credentials {
            isCredentialsEnabledSwitch.isOn = true
            userNameLabel.isEnabled = true
            passwordLabel.isEnabled = true
            userNameTextField.isEnabled = true
            passwordTextField.isEnabled = true
            saveButtonItem?.isEnabled = credentials.isValid
        } else {
            isCredentialsEnabledSwitch.isOn = false
            userNameLabel.isEnabled = false
            passwordLabel.isEnabled = false
            userNameTextField.isEnabled = false
            passwordTextField.isEnabled = false
            saveButtonItem?.isEnabled = true
        }
    }

    private func currentCredentials() -> OpenVPNConfigCredentials? {
        guard isCredentialsEnabledSwitch.isOn else { return nil }
        return OpenVPNConfigCredentials(
            userName: userNameTextField.text ?? "",
            passwordStrategy: .useSavedPassword(passwordTextField.text ?? ""))
    }

    private func saveCurrentCredentials() -> Bool {
        let credentials = currentCredentials()
        if credentials?.isValid ?? true {
            self.onCredentialsSaved?(credentials)
            return true
        }
        return false
    }

    @IBAction func isCredentialsEnabledSwitchToggled(_ sender: Any) {
        updateControlsState(with: currentCredentials())
    }

    @objc private func updateSaveButtonState(_ notification: Notification) {
        saveButtonItem?.isEnabled = currentCredentials()?.isValid ?? true
    }

    @objc func saveTapped(_ sender: Any) {
        let isSaved = saveCurrentCredentials()
        if isSaved {
            presentingViewController?.dismiss(animated: true, completion: nil)
        }
    }

    @objc func cancelTapped(_ sender: Any) {
        presentingViewController?.dismiss(animated: true, completion: nil)
        self.onCancelled?()
    }
}

extension CredentialsViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == userNameTextField {
            if !(userNameTextField.text ?? "").isEmpty {
                passwordTextField.becomeFirstResponder()
            }
        } else if textField == passwordTextField {
            let isSaved = saveCurrentCredentials()
            if isSaved {
                presentingViewController?.dismiss(animated: true, completion: nil)
            }
        }
        return false
    }
}
