//
//  AddServerViewController.swift
//  EduVPN
//

#if os(macOS)
import AppKit
#endif

import PromiseKit
import os.log

protocol AddServerViewControllerDelegate: class {
    func addServerViewController(
        _ controller: AddServerViewController,
        addedSimpleServerWithBaseURL baseURLString: DiscoveryData.BaseURLString,
        authState: AuthState)
}

final class AddServerViewController: ViewController, ParametrizedViewController {
    struct Parameters {
        let environment: Environment
        let preDefinedProvider: PreDefinedProvider?
    }

    weak var delegate: AddServerViewControllerDelegate?

    private var parameters: Parameters!

    @IBOutlet weak var topImageView: NSImageView!
    @IBOutlet weak var topLabel: NSTextField!
    @IBOutlet weak var serverURLTextField: NSTextField!
    @IBOutlet weak var addServerButton: NSButton!

    private var shouldAutoFocusURLField: Bool = true

    func initializeParameters(_ parameters: Parameters) {
        guard self.parameters == nil else {
            fatalError("Can't initialize parameters twice")
        }
        self.parameters = parameters
    }

    override func viewDidLoad() {
        if let preDefinedProvider = parameters.preDefinedProvider {
            topImageView.image = NSImage(named: "PreDefinedProviderTopImage")
            topLabel.text = preDefinedProvider.displayName.stringForCurrentLanguage()
            serverURLTextField.isHidden = true
            addServerButton.isEnabled = true
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
    #endif

    @IBAction func addServerClicked(_ sender: Any) {
        startAuth()
    }

    @IBAction func serverURLTextFieldReturnPressed(_ sender: Any) {
        startAuth()
    }

    private func serverBaseURLString() -> DiscoveryData.BaseURLString? {
        if let preDefinedProvider = parameters.preDefinedProvider {
            return preDefinedProvider.baseURLString
        }
        var urlString = serverURLTextField.text ?? ""
        guard !urlString.isEmpty else { return nil }
        if !urlString.hasPrefix("https://") {
            urlString = "https://" + urlString
        }
        if !urlString.hasSuffix("/") {
            urlString += "/"
        }
        return DiscoveryData.BaseURLString(urlString: urlString)
    }

    private func startAuth() {
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
}

extension AddServerViewController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        let urlString = serverURLTextField.text ?? ""
        let hasTwoOrMoreDots = urlString.filter { $0 == "." }.count >= 2
        addServerButton.isEnabled = hasTwoOrMoreDots
    }
}

#if os(macOS)
extension AddServerViewController: AuthorizingViewController {
    var navigationController: NavigationController? { parameters.environment.navigationController }

    func didBeginFetchingServerInfoForAuthorization(userCancellationHandler: (() -> Void)?) {
        navigationController?.showAuthorizingMessage(onCancelled: userCancellationHandler)
    }

    func didBeginAuthorization(macUserCancellationHandler: (() -> Void)?) {
        navigationController?.showAuthorizingMessage(onCancelled: macUserCancellationHandler)
    }

    func didEndAuthorization() {
        navigationController?.hideAuthorizingMessage()
        NSApp.activate(ignoringOtherApps: true)
    }
}
#endif
