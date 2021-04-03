//
//  CredentialsViewController.swift
//  EduVPN

// Allows entry of username / password for OpenVPN configs
// that require that.

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

final class CredentialsViewController: ViewController, ParametrizedViewController {

    struct Parameters {
        let initialCredentials: OpenVPNConfigCredentials?
    }

    private var parameters: Parameters!

    var onCredentialsSaved: ((OpenVPNConfigCredentials?) -> Void)?
    var onCancelled: (() -> Void)?

    #if os(macOS)
    @IBOutlet weak var isCredentialsEnabledCheckbox: NSButton!
    @IBOutlet weak var userNameTextField: NSTextField!
    @IBOutlet weak var passwordStrategyPopUp: NSPopUpButton!
    @IBOutlet weak var passwordTextField: NSSecureTextField!
    @IBOutlet weak var cancelButton: NSButton!
    @IBOutlet weak var saveButton: NSButton!
    #endif

    func initializeParameters(_ parameters: Parameters) {
        guard self.parameters == nil else {
            fatalError("Can't initialize parameters twice")
        }
        self.parameters = parameters
    }

    override func viewDidLoad() {
        setup(with: parameters.initialCredentials)
    }
}
