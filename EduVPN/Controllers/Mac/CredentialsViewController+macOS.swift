//
//  CredentialsViewController+macOS.swift
//  EduVPN
//

import AppKit

extension CredentialsViewController {
    func setup(with credentials: OpenVPNConfigCredentials?) {
        if let credentials = credentials {
            userNameTextField.text = credentials.userName
            if case .useSavedPassword(let password) = credentials.passwordStrategy {
                passwordTextField.text = password
            }
        }
        updateControlsState(with: credentials)
    }

    private func updateControlsState(with credentials: OpenVPNConfigCredentials?) {
        if let credentials = credentials {
            isCredentialsEnabledCheckbox.state = .on
            userNameTextField.isEnabled = true
            passwordStrategyPopUp.isEnabled = true
            switch credentials.passwordStrategy {
            case .useSavedPassword:
                passwordStrategyPopUp.selectItem(at: 0)
                passwordTextField.isHidden = false
                passwordTextField.isEnabled = true
            case .askForPasswordWhenConnecting:
                passwordStrategyPopUp.selectItem(at: 1)
                passwordTextField.isHidden = true
                passwordTextField.isEnabled = false
            }
            saveButton.isEnabled = credentials.isValid
        } else {
            isCredentialsEnabledCheckbox.state = .off
            userNameTextField.isEnabled = false
            passwordStrategyPopUp.isEnabled = false
            passwordTextField.isEnabled = false
            saveButton.isEnabled = true
        }
    }

    private func currentCredentials() -> OpenVPNConfigCredentials? {
        guard isCredentialsEnabledCheckbox.state == .on else { return nil }
        let userName = userNameTextField.text ?? ""
        let passwordStrategy: OpenVPNConfigCredentials.PasswordStrategy = {
            if passwordStrategyPopUp.indexOfSelectedItem == 0 {
                return .useSavedPassword(passwordTextField.text ?? "")
            }
            return .askForPasswordWhenConnecting
        }()
        return OpenVPNConfigCredentials(
            userName: userName, passwordStrategy: passwordStrategy)
    }

    @IBAction func credentialsEnabledCheckboxToggled(_ sender: Any) {
        updateControlsState(with: currentCredentials())
    }

    @IBAction func passwordStrategyPopupChanged(_ sender: Any) {
        updateControlsState(with: currentCredentials())
    }

    @IBAction func saveButtonClicked(_ sender: Any) {
        self.presentingViewController?.dismiss(self)
        self.onCredentialsSaved?(currentCredentials())
    }

    @IBAction func cancelButtonClicked(_ sender: Any) {
        self.presentingViewController?.dismiss(self)
        self.onCancelled?()
    }
}

extension CredentialsViewController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        saveButton.isEnabled = currentCredentials()?.isValid ?? true
    }
}
