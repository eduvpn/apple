//
//  AddServerViewController.swift
//  EduVPN
//

#if os(macOS)
import AppKit
#endif

import PromiseKit
import os.log

protocol AddServerViewControllerDelegate: AnyObject {
    func addServerViewController(
        _ controller: AddServerViewController,
        addedSimpleServerWithBaseURL baseURLString: DiscoveryData.BaseURLString,
        authState: AuthState)
}

final class AddServerViewController: ViewController, ParametrizedViewController {
    struct Parameters {
        let environment: Environment
        let predefinedProvider: PredefinedProvider?
        let shouldAutoFocusURLField: Bool
    }

    weak var delegate: AddServerViewControllerDelegate?

    private var parameters: Parameters!

    #if os(macOS)
    var navigationController: NavigationController? { parameters.environment.navigationController }
    #endif

    #if os(iOS)
    var contactingServerAlert: UIAlertController?
    #endif

    @IBOutlet weak var topImageView: ImageView!
    @IBOutlet weak var topLabel: Label!
    @IBOutlet weak var serverURLTextField: TextField!
    @IBOutlet weak var addServerButton: Button!

    private var shouldAutoFocusURLField: Bool = false

    var isBusy: Bool = false {
        didSet { updateIsUserAllowedToGoBack() }
    }
    private(set) var hasAddedServers: Bool = false {
        didSet { updateIsUserAllowedToGoBack() }
    }

    func initializeParameters(_ parameters: Parameters) {
        guard self.parameters == nil else {
            fatalError("Can't initialize parameters twice")
        }
        self.parameters = parameters
        self.shouldAutoFocusURLField = parameters.shouldAutoFocusURLField
    }

    override func viewDidLoad() {
        title = NSLocalizedString("Add Server", comment: "Search / Add server screen title")

        let persistenceService = parameters.environment.persistenceService
        persistenceService.hasServersDelegate = self
        hasAddedServers = persistenceService.hasServers

        if let predefinedProvider = parameters.predefinedProvider {
            topImageView.image = Image(named: "PredefinedProviderTopImage")
            topLabel.text = predefinedProvider.displayName.stringForCurrentLanguage()
            let buttonTitle = NSLocalizedString("Login", comment: "button title")
            #if os(macOS)
            addServerButton.title = buttonTitle
            #elseif os(iOS)
            addServerButton.setTitle(buttonTitle, for: .normal)
            #endif
            serverURLTextField.isHidden = true
            addServerButton.isEnabled = true
            shouldAutoFocusURLField = false
        }
    }

    #if os(macOS)
    override func viewDidAppear() {
        if shouldAutoFocusURLField {
            self.view.window?.makeFirstResponder(serverURLTextField)
        }
        shouldAutoFocusURLField = false
        super.viewDidAppear()
    }
    #elseif os(iOS)
    override func viewDidAppear(_ animated: Bool) {
        if shouldAutoFocusURLField {
            serverURLTextField.becomeFirstResponder()
        }
        shouldAutoFocusURLField = false
        super.viewDidAppear(animated)
    }
    #endif

    private func serverBaseURLString() -> DiscoveryData.BaseURLString? {
        if let predefinedProvider = parameters.predefinedProvider {
            return predefinedProvider.baseURLString
        }
        var urlString = serverURLTextField.text ?? ""
        guard !urlString.isEmpty else { return nil }
        if !urlString.hasPrefix("https://") {
            urlString = "https://" + urlString
        }
        if !urlString.hasSuffix("/") {
            urlString += "/"
        }
        let hasTwoOrMoreDots = urlString.filter { $0 == "." }.count >= 2
        guard hasTwoOrMoreDots else { return nil }
        return DiscoveryData.BaseURLString(urlString: urlString)
    }

    func startAuth() {
        guard let baseURLString = serverBaseURLString() else { return }
        let serverAuthService = parameters.environment.serverAuthService
        let navigationController = parameters.environment.navigationController
        let delegate = self.delegate

        firstly {
            serverAuthService.startAuth(
                baseURLString: baseURLString,
                from: self, wayfSkippingInfo: nil)
        }.map { authState in
            delegate?.addServerViewController(
                self, addedSimpleServerWithBaseURL: baseURLString,
                authState: authState)
        }.catch { error in
            os_log("Error during authentication: %{public}@",
                   log: Log.general, type: .error,
                   error.localizedDescription)
            if !serverAuthService.isUserCancelledError(error) {
                navigationController?.showAlert(for: error)
            }
        }
    }

    func onServerURLTextFieldTextChanged() {
        let urlString = serverURLTextField.text ?? ""
        let hasTwoOrMoreDots = urlString.filter { $0 == "." }.count >= 2
        addServerButton.isEnabled = hasTwoOrMoreDots
    }

    func updateIsUserAllowedToGoBack() {
        parameters.environment.navigationController?.isUserAllowedToGoBack = hasAddedServers && !isBusy
    }
}

extension AddServerViewController: PersistenceServiceHasServersDelegate {
    func persistenceService(_ persistenceService: PersistenceService, hasServersChangedTo hasServers: Bool) {
        hasAddedServers = hasServers
    }
}
