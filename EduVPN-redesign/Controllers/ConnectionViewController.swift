//
//  ConnectionViewController.swift
//  EduVPN
//
//  Created by Johan Kool on 28/05/2020.
//

import Foundation
import PromiseKit
import os.log

protocol ConnectionViewControllerDelegate: class {
    func connectionViewController(
        _ controller: ConnectionViewController,
        willAttemptToConnect connectionAttempt: ConnectionAttempt?)
}

enum ConnectionViewControllerError: Error {
    case noProfiles
    case noSelectedProfile
    case noProfileFoundWithSelectedProfileId
}

extension ConnectionViewControllerError: AppError {
    var summary: String {
        switch self {
        case .noProfiles: return "No profiles found"
        case .noSelectedProfile: return "No profile selected"
        case .noProfileFoundWithSelectedProfileId: return "Selected profile doesn't exist"
        }
    }
}

final class ConnectionViewController: ViewController, ParametrizedViewController {

    struct Parameters {
        let environment: Environment
        let server: ServerInstance
        let serverDisplayInfo: ServerDisplayInfo
        let authURLTemplate: String?
        let restoredPreConnectionState: ConnectionAttempt.PreConnectionState?
    }

    weak var delegate: ConnectionViewControllerDelegate?

    private var parameters: Parameters!
    private var isRestored: Bool = false
    private var viewModel: ConnectionViewModel!
    private var dataStore: PersistenceService.DataStore!

    private var profiles: [ProfileListResponse.Profile]?
    private var selectedProfileId: String? {
        didSet {
            dataStore.setSelectedProfileId(
                profileId: selectedProfileId,
                for: parameters.server.apiBaseURLString)
        }
    }

    @IBOutlet weak var serverNameLabel: Label!
    @IBOutlet weak var serverCountryFlagImageView: ImageView!

    @IBOutlet weak var supportContactStackView: StackView!

    #if os(macOS)
    var supportContactTextView: NSTextView!
    #elseif os(iOS)
    @IBOutlet weak var supportContactTextView: UITextView!
    #endif

    @IBOutlet weak var connectionStatusImageView: ImageView!
    @IBOutlet weak var statusLabel: Label!
    @IBOutlet weak var statusDetailLabel: Label!

    @IBOutlet weak var vpnSwitch: Button!

    @IBOutlet weak var bottomStackView: StackView!

    @IBOutlet weak var additionalControlContainer: View!
    @IBOutlet weak var profileSelectionView: View!
    @IBOutlet weak var renewSessionButton: Button!
    @IBOutlet weak var spinner: Spinner!

    #if os(macOS)
    @IBOutlet weak var profileSelectorPopupButton: NSPopUpButton!
    #elseif os(iOS)
    @IBOutlet weak var profileRowNameLabel: UILabel!
    #endif

    #if os(macOS)
    @IBOutlet weak var connectionInfoHeader: ConnectionInfoHeaderView!
    @IBOutlet weak var connectionInfoChevronButton: NSButton!
    #elseif os(iOS)
    @IBOutlet weak var connectionInfoHeader: View!
    #endif

    #if os(macOS)
    @IBOutlet weak var connectionInfoBody: NSView!
    @IBOutlet weak var durationLabel: NSTextField!
    @IBOutlet weak var profileTitleLabel: NSTextField!
    @IBOutlet weak var profileNameLabel: NSTextField!
    @IBOutlet weak var dataTransferredLabel: NSTextField!
    @IBOutlet weak var addressLabel: NSTextField!
    #endif

    @IBOutlet weak var serverCountryFlagImageWidthConstraint: NSLayoutConstraint!
    // swiftlint:disable:next identifier_name
    @IBOutlet weak var additionalControlContainerHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var connectionInfoBodyHeightConstraint: NSLayoutConstraint!

    #if os(iOS)
    @IBOutlet weak var connectionInfoHeaderHeightConstraint: NSLayoutConstraint!
    #endif

    func initializeParameters(_ parameters: Parameters) {
        guard self.parameters == nil else {
            fatalError("Can't initialize parameters twice")
        }
        self.parameters = parameters

        self.viewModel = ConnectionViewModel(
            serverAPIService: parameters.environment.serverAPIService,
            connectionService: parameters.environment.connectionService,
            server: parameters.server,
            serverDisplayInfo: parameters.serverDisplayInfo,
            authURLTemplate: parameters.authURLTemplate,
            restoredPreConnectionState: parameters.restoredPreConnectionState)
        self.dataStore = PersistenceService.DataStore(path: parameters.server.localStoragePath)

        if let restoredPreConnectionState = parameters.restoredPreConnectionState {
            self.profiles = restoredPreConnectionState.profiles
            self.selectedProfileId = restoredPreConnectionState.selectedProfileId
            self.isRestored = true
        } else {
            self.selectedProfileId = dataStore.selectedProfileId(for: parameters.server.apiBaseURLString)
            self.isRestored = false
        }
    }

    override func viewDidLoad() {
        title = NSLocalizedString("Connect to Server", comment: "")
        // The view model delegate is set only after our views are ready
        // to receive updates from the view model
        viewModel.delegate = self
        setupInitialView(viewModel: viewModel)
        if !isRestored {
            beginConnectionFlow(shouldContinueIfSingleProfile: true)
        }
    }

    #if os(macOS)
    @IBAction func vpnSwitchToggled(_ sender: Any) {
        vpnSwitchToggled()
    }
    #elseif os(iOS)
    @IBAction func vpnSwitchTapped(_ sender: Any) {
        vpnSwitch.isOn = !vpnSwitch.isOn
        vpnSwitchToggled()
    }
    #endif

    func vpnSwitchToggled() {
        if vpnSwitch.isOn {
            guard let profiles = profiles, !profiles.isEmpty else {
                beginConnectionFlow(shouldContinueIfSingleProfile: true)
                return
            }
            if selectedProfileId == nil {
                selectedProfileId = profiles[0].profileId
            }
            continueConnectionFlow(serverAPIOptions: [])
        } else {
            disableVPN()
        }
    }

    func profileSelected(selectedIndex: Int) {
        if let profiles = profiles,
            selectedIndex >= 0,
            selectedIndex < profiles.count {
            selectedProfileId = profiles[selectedIndex].profileId
        }
    }

    @IBAction func renewSessionClicked(_ sender: Any) {
        continueConnectionFlow(serverAPIOptions: [.ignoreStoredAuthState, .ignoreStoredKeyPair])
    }

    #if os(macOS)
    @IBAction func profileSelected(_ sender: Any) {
        profileSelected(selectedIndex: profileSelectorPopupButton.indexOfSelectedItem)
    }

    @IBAction func connectionInfoChevronClicked(_ sender: Any) {
        viewModel.toggleConnectionInfoExpanded()
    }
    #endif

    #if os(iOS)
    @IBAction func profileSelectionRowTapped(_ sender: Any) {
        guard let profiles = self.profiles else { return }
        var items: [ItemSelectionViewController.Item] = []
        var selectedIndex = -1
        for (index, profile) in profiles.enumerated() {
            let item = ItemSelectionViewController.Item(profile.displayName.string(for: Locale.current))
            items.append(item)
            if profile.profileId == selectedProfileId {
                selectedIndex = index
            }
        }
        let selectionVC = parameters.environment.instantiateItemSelectionViewController(
            items: items, selectedIndex: selectedIndex)
        selectionVC.title = NSLocalizedString("Select a profile", comment: "")
        selectionVC.delegate = self
        let navigationVC = UINavigationController(rootViewController: selectionVC)
        navigationVC.modalPresentationStyle = .pageSheet
        present(navigationVC, animated: true, completion: nil)
    }
    #endif
}

#if os(iOS)
extension ConnectionViewController: ItemSelectionViewControllerDelegate {
    func itemSelectionViewController(_ viewController: ItemSelectionViewController, didSelectIndex index: Int) {
        profileSelected(selectedIndex: index)
        if let selectedProfile = profiles?[index] {
            profileRowNameLabel.text = selectedProfile.displayName.string(for: Locale.current)
        } else {
            profileRowNameLabel.text = NSLocalizedString("Unknown", comment: "Unknown profile")
        }
    }
}
#endif

private extension ConnectionViewController {
    func setupInitialView(viewModel: ConnectionViewModel) {
        connectionViewModel(viewModel, canGoBackChanged: viewModel.canGoBack)
        connectionViewModel(viewModel, headerChanged: viewModel.header)
        setupSupportContact(supportContact: viewModel.supportContact)
        connectionViewModel(viewModel, statusChanged: viewModel.status)
        connectionViewModel(viewModel, statusDetailChanged: viewModel.statusDetail)
        connectionViewModel(viewModel, vpnSwitchStateChanged: viewModel.vpnSwitchState)
        connectionViewModel(viewModel, additionalControlChanged: viewModel.additionalControl)
        connectionInfoStateChanged(viewModel.connectionInfoState, animated: false)
    }

    func setupSupportContact(supportContact: ConnectionViewModel.SupportContact) {
        self.supportContactStackView.isHidden = supportContact.isEmpty

        #if os(macOS)
        let supportContactTextView = SupportContactTextView(supportContact: supportContact)
        supportContactStackView.addView(supportContactTextView, in: .leading)
        self.supportContactTextView = supportContactTextView
        #elseif os(iOS)
        self.supportContactTextView.attributedText = supportContact.attributedString
        #endif
    }

    func beginConnectionFlow(shouldContinueIfSingleProfile: Bool) {
        firstly {
            viewModel.beginConnectionFlow(from: self, shouldContinueIfSingleProfile: shouldContinueIfSingleProfile)
        }.catch { error in
            os_log("Error beginning connection flow: %{public}@",
                   log: Log.general, type: .error,
                   error.localizedDescription)
            self.showAlert(for: error)
        }
    }

    func continueConnectionFlow(serverAPIOptions: ServerAPIService.Options) {
        firstly { () -> Promise<Void> in
            guard let profiles = profiles, !profiles.isEmpty else {
                return Promise(error: ConnectionViewControllerError.noProfiles)
            }
            guard let selectedProfileId = selectedProfileId else {
                return Promise(error: ConnectionViewControllerError.noSelectedProfile)
            }
            guard let profile = profiles.first(where: { $0.profileId == selectedProfileId }) else {
                return Promise(error: ConnectionViewControllerError.noProfileFoundWithSelectedProfileId)
            }
            return viewModel.continueConnectionFlow(profile: profile, from: self,
                                                    serverAPIOptions: serverAPIOptions)
        }.catch { error in
            os_log("Error continuing connection flow: %{public}@",
                   log: Log.general, type: .error,
                   error.localizedDescription)
            self.showAlert(for: error)
        }
    }

    func disableVPN() {
        firstly {
            viewModel.disableVPN()
        }.catch { error in
            os_log("Error disabling VPN: %{public}@",
                   log: Log.general, type: .error,
                   error.localizedDescription)
            self.showAlert(for: error)
        }
    }

    private func showAlert(for error: Error) {
        if let serverAPIError = error as? ServerAPIServiceError,
            case ServerAPIServiceError.errorGettingProfileConfig = serverAPIError {

            // If there's an error getting profile config, offer to refresh profiles

            #if os(macOS)

            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = serverAPIError.summary
            alert.informativeText = serverAPIError.detail
            alert.addButton(withTitle: NSLocalizedString("Refresh Profiles", comment: ""))
            alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
            if let window = self.view.window {
                alert.beginSheetModal(for: window) { result in
                    if case .alertFirstButtonReturn = result {
                        self.beginConnectionFlow(shouldContinueIfSingleProfile: true)
                    }
                }
            }

            #elseif os(iOS)

            let alert = UIAlertController()
            let refreshAction = UIAlertAction(
                title: NSLocalizedString("Refresh Profiles", comment: ""),
                style: .default,
                handler: { _ in
                    self.beginConnectionFlow(shouldContinueIfSingleProfile: true)
                })
            let cancelAction = UIAlertAction(
                title: NSLocalizedString("Cancel", comment: ""),
                style: .cancel)
            alert.addAction(refreshAction)
            alert.addAction(cancelAction)
            present(alert, animated: true, completion: nil)

            #endif
            return
        }
        if !self.parameters.environment.serverAuthService.isUserCancelledError(error) {
            self.parameters.environment.navigationController?.showAlert(for: error)
        }
    }

}

extension ConnectionViewController: ConnectionViewModelDelegate {

    func connectionViewModel(
        _ model: ConnectionViewModel, foundProfiles profiles: [ProfileListResponse.Profile]) {
        self.profiles = profiles
        if let selectedProfileId = selectedProfileId {
            if !profiles.contains(where: { $0.profileId == selectedProfileId }) {
                // The current selectedProfileId is invalid
                self.selectedProfileId = nil
            }
        }
    }

    func connectionViewModel(
        _ model: ConnectionViewModel, canGoBackChanged canGoBack: Bool) {
        parameters.environment.navigationController?.isUserAllowedToGoBack = canGoBack
    }

    func connectionViewModel(
        _ model: ConnectionViewModel, willAutomaticallySelectProfileId profileId: String) {
        selectedProfileId = profileId
    }

    func connectionViewModel(
        _ model: ConnectionViewModel,
        willAttemptToConnectWithProfileId profileId: String,
        certificateValidityRange: ServerAPIService.CertificateValidityRange,
        connectionAttemptId: UUID) {
        let connectionAttempt = ConnectionAttempt(
            server: parameters.server, profiles: profiles ?? [],
            selectedProfileId: profileId,
            certificateValidityRange: certificateValidityRange,
            attemptId: connectionAttemptId)
        delegate?.connectionViewController(self, willAttemptToConnect: connectionAttempt)
    }

    static let serverCountryFlagImageWidth: CGFloat = 24

    func connectionViewModel(
        _ model: ConnectionViewModel, headerChanged header: ConnectionViewModel.Header) {
        serverNameLabel.text = header.serverName
        if header.flagCountryCode.isEmpty {
            serverCountryFlagImageView.image = nil
            serverCountryFlagImageWidthConstraint.constant = 0
        } else {
            serverCountryFlagImageView.image = Image(named: "CountryFlag_\(header.flagCountryCode)")
            serverCountryFlagImageWidthConstraint.constant = Self.serverCountryFlagImageWidth
        }
    }

    func connectionViewModel(
        _ model: ConnectionViewModel, statusChanged status: ConnectionViewModel.Status) {
        connectionStatusImageView.image = { () -> Image? in
            switch status {
            case .notConnected, .gettingProfiles, .configuring:
                return Image(named: "StatusNotConnected")
            case .connecting, .reconnecting, .disconnecting:
                return Image(named: "StatusConnecting")
            case .connected:
                return Image(named: "StatusConnected")
            }
        }()
        statusLabel.text = status.localizedText
    }

    func connectionViewModel(
        _ model: ConnectionViewModel,
        statusDetailChanged statusDetail: ConnectionViewModel.StatusDetail) {
        statusDetailLabel.text = statusDetail.localizedText
    }

    func connectionViewModel(
        _ model: ConnectionViewModel,
        vpnSwitchStateChanged vpnSwitchState: ConnectionViewModel.VPNSwitchState) {
        vpnSwitch.isEnabled = vpnSwitchState.isEnabled
        vpnSwitch.isOn = vpnSwitchState.isOn
    }

    func connectionViewModel(
        _ model: ConnectionViewModel,
        additionalControlChanged additionalControl: ConnectionViewModel.AdditionalControl) {
        switch additionalControl {
        case .none:
            profileSelectionView.isHidden = true
            renewSessionButton.isHidden = true
            spinner.stopAnimation(self)
        case .spinner:
            profileSelectionView.isHidden = true
            renewSessionButton.isHidden = true
            spinner.startAnimation(self)
        case .profileSelector(let profiles):
            profileSelectionView.isHidden = false
            renewSessionButton.isHidden = true
            spinner.stopAnimation(self)
            #if os(macOS)
            profileSelectorPopupButton.removeAllItems()
            var selectedIndex: Int?
            for (index, profile) in profiles.enumerated() {
                let profileName = profile.displayName.string(for: Locale.current)
                profileSelectorPopupButton.addItem(withTitle: profileName)
                if profile.profileId == selectedProfileId {
                    selectedIndex = index
                }
            }
            if let selectedIndex = selectedIndex {
                profileSelectorPopupButton.selectItem(at: selectedIndex)
            }
            profileSelectorPopupButton.isEnabled = true
            #elseif os(iOS)
            if let selectedProfile = profiles.first(where: { $0.profileId == selectedProfileId }) {
                profileRowNameLabel.text = selectedProfile.displayName.string(for: Locale.current)
            } else if let firstProfile = profiles.first {
                profileRowNameLabel.text = firstProfile.displayName.string(for: Locale.current)
            } else {
                profileRowNameLabel.text = NSLocalizedString("Unknown", comment: "Unknown profile")
            }
            #endif
            self.profiles = profiles
        case .renewSessionButton:
            profileSelectionView.isHidden = true
            renewSessionButton.isHidden = false
            spinner.stopAnimation(self)
        }
    }

    static let connectionInfoHeaderHeight: CGFloat = 46
    static let connectionInfoBodyHeight: CGFloat = 100
    #if os(macOS)
    static let additionalControlContainerHeight = connectionInfoBodyHeight
    #elseif os(iOS)
    static let additionalControlContainerHeight: CGFloat = 46
    #endif

    func connectionViewModel(
        _ model: ConnectionViewModel,
        connectionInfoStateChanged connectionInfoState: ConnectionViewModel.ConnectionInfoState) {
        connectionInfoStateChanged(connectionInfoState, animated: true)
    }

    // swiftlint:disable:next function_body_length
    func connectionInfoStateChanged(
        _ connectionInfoState: ConnectionViewModel.ConnectionInfoState, animated: Bool) {
        let controlAlpha: Float
        let controlHeight: CGFloat
        let headerAlpha: Float
        let headerHeight: CGFloat
        let bodyAlpha: Float
        let bodyHeight: CGFloat

        switch connectionInfoState {
        case .hidden:
            controlAlpha = 1
            controlHeight = Self.additionalControlContainerHeight
            headerAlpha = 0
            headerHeight = Self.connectionInfoHeaderHeight
            bodyAlpha = 0
            bodyHeight = 0
        case .collapsed:
            controlAlpha = 1
            controlHeight = Self.additionalControlContainerHeight
            headerAlpha = 1
            headerHeight = Self.connectionInfoHeaderHeight
            bodyAlpha = 0
            bodyHeight = 0
        case .expanded(let connectionInfo):
            #if os(macOS)

            controlAlpha = 0
            controlHeight = 0
            headerAlpha = 1
            headerHeight = Self.connectionInfoHeaderHeight
            bodyAlpha = 1
            bodyHeight = Self.connectionInfoBodyHeight
            durationLabel.stringValue = connectionInfo.duration
            if let profileName = connectionInfo.profileName {
                profileTitleLabel.isHidden = false
                profileNameLabel.stringValue = profileName
            } else {
                profileTitleLabel.isHidden = true
                profileNameLabel.stringValue = ""
            }
            dataTransferredLabel.stringValue = connectionInfo.dataTransferred
            addressLabel.stringValue = connectionInfo.addresses

            #elseif os(iOS)

            controlAlpha = 1
            controlHeight = Self.additionalControlContainerHeight
            headerAlpha = 1
            headerHeight = Self.connectionInfoHeaderHeight
            bodyAlpha = 0
            bodyHeight = 0

            #endif
        }

        #if os(macOS)
        switch connectionInfoState {
        case .hidden:
            connectionInfoChevronButton.image = Image(named: "ChevronDownButton")
            connectionInfoHeader.isPassthroughToButtonEnabled = false
        case .collapsed:
            connectionInfoChevronButton.image = Image(named: "ChevronDownButton")
            connectionInfoHeader.isPassthroughToButtonEnabled = true // Make whole "row" clickable
        case .expanded:
            connectionInfoChevronButton.image = Image(named: "CloseButton")
            connectionInfoHeader.isPassthroughToButtonEnabled = false
        }
        #endif

        let animatableChanges = {
            self.additionalControlContainer.setLayerOpacity(controlAlpha)
            self.additionalControlContainerHeightConstraint.constant = controlHeight
            self.connectionInfoHeader.setLayerOpacity(headerAlpha)
            _ = headerHeight // Avoid warning
            #if os(macOS)
            self.connectionInfoBody.setLayerOpacity(bodyAlpha)
            self.connectionInfoBodyHeightConstraint.constant = bodyHeight
            #endif
            self.bottomStackView.layoutIfNeeded()
        }

        if animated {
            performWithAnimation(seconds: 0.3) {
                animatableChanges()
            }
        } else {
            animatableChanges()
        }
    }
}

extension ConnectionViewController: AuthorizingViewController {
    func didBeginFetchingServerInfoForAuthorization(userCancellationHandler: (() -> Void)?) {
        fatalError("Fetching server.json is not necessary during authorization")
    }

    #if os(macOS)
    func didBeginAuthorization(macUserCancellationHandler: (() -> Void)?) {
        parameters.environment.navigationController?
            .showAuthorizingMessage(onCancelled: macUserCancellationHandler)
    }

    func didEndAuthorization() {
        parameters.environment.navigationController?
            .hideAuthorizingMessage()
        NSApp.activate(ignoringOtherApps: true)
    }
    #elseif os(iOS)
    func didBeginAuthorization(macUserCancellationHandler: (() -> Void)?) {
        // Nothing to do
    }

    func didEndAuthorization() {
        // Nothing to do
    }
    #endif
}
