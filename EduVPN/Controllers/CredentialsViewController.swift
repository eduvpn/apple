//
//  CredentialsViewController.swift
//  EduVPN

// Allows entry of username / password for OpenVPN configs
// that require that.

#if os(macOS)
import AppKit
#endif

final class CredentialsViewController: ViewController, ParametrizedViewController {

    struct Parameters {
        let initialCredentials: OpenVPNConfigCredentials?
    }

    private var parameters: Parameters!

    var onCredentialsSaved: ((OpenVPNConfigCredentials?) -> Void)?
    var onCancelled: (() -> Void)?

    @IBOutlet weak var isCredentialsEnabledCheckbox: NSButton!
    @IBOutlet weak var userNameTextField: NSTextField!
    @IBOutlet weak var passwordStrategyPopUp: NSPopUpButton!
    @IBOutlet weak var passwordTextField: NSSecureTextField!
    @IBOutlet weak var cancelButton: NSButton!
    @IBOutlet weak var saveButton: NSButton!

    func initializeParameters(_ parameters: Parameters) {
        guard self.parameters == nil else {
            fatalError("Can't initialize parameters twice")
        }
        self.parameters = parameters
    }

    override func viewDidLoad() {
        setup(with: parameters.initialCredentials)
    }

    private func setup(with credentials: OpenVPNConfigCredentials?) {
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
