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

#if os(macOS)
typealias CredentialsViewControllerBase = NSViewController
#elseif os(iOS)
typealias CredentialsViewControllerBase = UITableViewController
#endif

final class CredentialsViewController: CredentialsViewControllerBase, ParametrizedViewController {
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
    #elseif os(iOS)
    @IBOutlet weak var isCredentialsEnabledSwitch: UISwitch!
    @IBOutlet weak var userNameTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    var cancelButtonItem: UIBarButtonItem?
    var saveButtonItem: UIBarButtonItem?
    var textFieldObservationToken: AnyObject?
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
