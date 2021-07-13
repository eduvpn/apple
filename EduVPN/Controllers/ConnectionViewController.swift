//
//  ConnectionViewController.swift
//  EduVPN
//
//  Created by Johan Kool on 28/05/2020.
//

import Foundation
import PromiseKit
import os.log

protocol ConnectionViewControllerDelegate: AnyObject {
    func connectionViewController(
        _ controller: ConnectionViewController,
        flowStatusChanged status: ConnectionViewModel.ConnectionFlowStatus)
    func connectionViewController(
        _ controller: ConnectionViewController,
        willAttemptToConnect connectionAttempt: ConnectionAttempt?)
    func connectionViewController(
        _ controller: ConnectionViewController,
        isVPNTogglableBecame isTogglable: Bool)
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

// swiftlint:disable:next type_body_length
final class ConnectionViewController: ViewController, ParametrizedViewController {

    struct Parameters {
        let environment: Environment
        let connectableInstance: ConnectableInstance
        let serverDisplayInfo: ServerDisplayInfo
        let authURLTemplate: String?
        let initialConnectionFlowContinuationPolicy: ConnectionViewModel.FlowContinuationPolicy

        // If restoringPreConnectionState is non-nil, then we're restoring
        // the UI at app launch for an already-on VPN
        let restoringPreConnectionState: ConnectionAttempt.PreConnectionState?
    }

    weak var delegate: ConnectionViewControllerDelegate?

    var connectableInstance: ConnectableInstance {
        parameters.connectableInstance
    }

    var serverDisplayInfo: ServerDisplayInfo {
        parameters.serverDisplayInfo
    }

    var status: ConnectionViewModel.ConnectionFlowStatus {
        viewModel.status
    }

    private var parameters: Parameters!
    private var isRestored: Bool = false
    private var viewModel: ConnectionViewModel!
    private var dataStore: PersistenceService.DataStore!

    private var profiles: [Profile]?
    private var selectedProfileId: String? {
        didSet {
            if let server = parameters.connectableInstance as? ServerInstance {
                dataStore?.setSelectedProfileId(
                    profileId: selectedProfileId,
                    for: server.apiBaseURLString)
            }
        }
    }

    @IBOutlet weak var serverNameLabel: Label!
    @IBOutlet weak var serverCountryFlagImageView: ImageView!

    #if os(macOS)
    @IBOutlet weak var supportContactStackView: StackView!
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
    @IBOutlet weak var setCredentialsButton: Button!
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
    @IBOutlet weak var vpnProtocolLabel: NSTextField!
    @IBOutlet weak var dataTransferredLabel: NSTextField!
    @IBOutlet weak var addressLabel: NSTextField!
    #endif

    @IBOutlet weak var serverCountryFlagImageWidthConstraint: NSLayoutConstraint!
    // swiftlint:disable:next identifier_name
    @IBOutlet weak var additionalControlContainerHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var connectionInfoBodyHeightConstraint: NSLayoutConstraint!

    #if os(iOS)
    weak var presentedConnectionInfoVC: ConnectionInfoViewController?
    #endif

    #if os(macOS)
    var presentedPasswordEntryVC: PasswordEntryViewController?
    #endif

    func initializeParameters(_ parameters: Parameters) {
        guard self.parameters == nil else {
            fatalError("Can't initialize parameters twice")
        }
        self.parameters = parameters

        if let server = parameters.connectableInstance as? ServerInstance {
            let serverPreConnectionState = parameters.restoringPreConnectionState?.serverState
            self.viewModel = ConnectionViewModel(
                server: server,
                connectionService: parameters.environment.connectionService,
                notificationService: parameters.environment.notificationService,
                serverDisplayInfo: parameters.serverDisplayInfo,
                serverAPIService: parameters.environment.serverAPIService,
                authURLTemplate: parameters.authURLTemplate,
                restoringPreConnectionState: serverPreConnectionState)
        } else if let vpnConfigInstance = parameters.connectableInstance as? VPNConfigInstance {
            let vpnConfigPreConnectionState = parameters.restoringPreConnectionState?.vpnConfigState
            self.viewModel = ConnectionViewModel(
                vpnConfigInstance: vpnConfigInstance,
                connectionService: parameters.environment.connectionService,
                serverDisplayInfo: parameters.serverDisplayInfo,
                restoringPreConnectionState: vpnConfigPreConnectionState)
        } else {
            fatalError("Unknown connectable instance: \(parameters.connectableInstance)")
        }

        self.isRestored = (parameters.restoringPreConnectionState != nil)
        self.dataStore = PersistenceService.DataStore(path: parameters.connectableInstance.localStoragePath)

        if let server = parameters.connectableInstance as? ServerInstance {
            let serverPreConnectionState = parameters.restoringPreConnectionState?.serverState
            if let serverPreConnectionState = serverPreConnectionState {
                self.profiles = serverPreConnectionState.profiles
                self.selectedProfileId = serverPreConnectionState.selectedProfileId
            } else {
                self.profiles = []
                self.selectedProfileId = dataStore.selectedProfileId(for: server.apiBaseURLString)
            }
        }
    }

    override func viewDidLoad() {
        title = NSLocalizedString("Connect to Server", comment: "Connection screen title")
        // The view model delegate is set only after our views are ready
        // to receive updates from the view model
        viewModel.delegate = self
        setupInitialView(viewModel: viewModel)
        if !isRestored {
            beginConnectionFlow(continuationPolicy: parameters.initialConnectionFlowContinuationPolicy)
        }
        #if os(macOS)
        vpnSwitch.setAccessibilityIdentifier("Connection")
        #elseif os(iOS)
        vpnSwitch.accessibilityIdentifier = "Connection"
        #endif
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

    func beginConnectionFlow(continuationPolicy: ConnectionViewModel.FlowContinuationPolicy) {
        if parameters.connectableInstance is ServerInstance {
            beginServerConnectionFlow(continuationPolicy: continuationPolicy)
        } else if parameters.connectableInstance is VPNConfigInstance {
            beginVPNConfigConnectionFlow()
        }
    }

    func vpnSwitchToggled() {
        if vpnSwitch.isOn {
            if parameters.connectableInstance is ServerInstance {
                guard let profiles = profiles, !profiles.isEmpty else {
                    beginServerConnectionFlow(continuationPolicy: .continueWithSingleOrLastUsedProfile)
                    return
                }
                if selectedProfileId == nil {
                    selectedProfileId = profiles[0].profileId
                }
                continueServerConnectionFlow(serverAPIOptions: [])
            } else if parameters.connectableInstance is VPNConfigInstance {
                beginVPNConfigConnectionFlow()
            }
        } else {
            disableVPN()
        }
    }

    @discardableResult
    func disableVPN() -> Promise<Void> {
        firstly {
            viewModel.disableVPN()
        }.map {
            self.vpnSwitch.isOn = false
        }.recover { error in
            os_log("Error disabling VPN: %{public}@",
                   log: Log.general, type: .error,
                   error.localizedDescription)
            self.showAlert(for: error)
        }
    }

    func profileSelected(selectedIndex: Int) {
        if let profiles = profiles,
            selectedIndex >= 0,
            selectedIndex < profiles.count {
            selectedProfileId = profiles[selectedIndex].profileId
        }
    }

    func renewSession() {
        firstly {
            viewModel.disableVPN()
        }.map {
            self.continueServerConnectionFlow(serverAPIOptions: [.ignoreStoredAuthState, .ignoreStoredKeyPair])
        }.catch { error in
            os_log("Error renewing session: %{public}@",
                   log: Log.general, type: .error,
                   error.localizedDescription)
            self.showAlert(for: error)
        }
    }

    func scheduleSessionExpiryNotificationOnActiveVPN() -> Guarantee<Bool> {
        viewModel.scheduleSessionExpiryNotificationOnActiveVPN()
    }

    @IBAction func renewSessionClicked(_ sender: Any) {
        renewSession()
    }

    @IBAction func setCredentialsClicked(_ sender: Any) {
        guard let vpnConfigInstance = parameters.connectableInstance as? VPNConfigInstance else {
            return
        }
        let credentialsVC = parameters.environment.instantiateCredentialsViewController(
            initialCredentials: dataStore.openVPNConfigCredentials)
        credentialsVC.onCredentialsSaved = { credentials in
            let dataStore = PersistenceService.DataStore(path: vpnConfigInstance.localStoragePath)
            dataStore.openVPNConfigCredentials = credentials
        }
        #if os(macOS)
        parameters.environment.navigationController?.presentAsSheet(credentialsVC)
        #elseif os(iOS)
        let navigationVC = UINavigationController(rootViewController: credentialsVC)
        navigationVC.modalPresentationStyle = .pageSheet
        present(navigationVC, animated: true, completion: nil)
        #endif
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
            let item = ItemSelectionViewController.Item(profile.displayName.stringForCurrentLanguage())
            items.append(item)
            if profile.profileId == selectedProfileId {
                selectedIndex = index
            }
        }
        let selectionVC = parameters.environment.instantiateItemSelectionViewController(
            items: items, selectedIndex: selectedIndex)
        selectionVC.title = NSLocalizedString(
            "Select a profile",
            comment: "iOS profile selection view title")
        selectionVC.delegate = self
        let navigationVC = UINavigationController(rootViewController: selectionVC)
        navigationVC.modalPresentationStyle = .pageSheet
        present(navigationVC, animated: true, completion: nil)
    }

    @IBAction func connectionInfoRowTapped(_ sender: Any) {
        viewModel.toggleConnectionInfoExpanded()
    }
    #endif

    func canGoBack() -> Bool {
        return parameters.environment.navigationController?.isUserAllowedToGoBack ?? false
    }

    func goBack() {
        parameters.environment.navigationController?.popViewController(animated: true)
    }
}

#if os(iOS)
extension ConnectionViewController: ItemSelectionViewControllerDelegate {
    func itemSelectionViewController(_ viewController: ItemSelectionViewController, didSelectIndex index: Int) {
        profileSelected(selectedIndex: index)
        if let selectedProfile = profiles?[index] {
            profileRowNameLabel.text = selectedProfile.displayName.stringForCurrentLanguage()
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
        setCredentialsButton.isHidden = !(parameters.connectableInstance is VPNConfigInstance)
    }

    func setupSupportContact(supportContact: ConnectionViewModel.SupportContact) {
        #if os(macOS)
        let supportContactTextView = SupportContactTextView(supportContact: supportContact)
        supportContactStackView.addView(supportContactTextView, in: .leading)
        self.supportContactTextView = supportContactTextView
        self.supportContactStackView.isHidden = supportContact.isEmpty
        #elseif os(iOS)
        self.supportContactTextView.attributedText = supportContact.attributedString
        #endif
    }

    func beginServerConnectionFlow(continuationPolicy: ConnectionViewModel.FlowContinuationPolicy) {
        firstly {
            viewModel.beginServerConnectionFlow(
                from: self, continuationPolicy: continuationPolicy, lastUsedProfileId: self.selectedProfileId)
        }.catch { error in
            os_log("Error beginning server connection flow: %{public}@",
                   log: Log.general, type: .error,
                   error.localizedDescription)
            self.showAlert(for: error)
        }
    }

    func continueServerConnectionFlow(serverAPIOptions: ServerAPIService.Options) {
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
            return viewModel.continueServerConnectionFlow(
                profile: profile, from: self, serverAPIOptions: serverAPIOptions)
        }.catch { error in
            os_log("Error continuing server connection flow: %{public}@",
                   log: Log.general, type: .error,
                   error.localizedDescription)
            self.showAlert(for: error)
        }
    }

    func beginVPNConfigConnectionFlow() {
        guard let vpnConfigInstance = parameters.connectableInstance as? VPNConfigInstance else {
            return
        }

        let dataStore = PersistenceService.DataStore(path: vpnConfigInstance.localStoragePath)
        let openVPNConfigCredentials = dataStore.openVPNConfigCredentials
        switch openVPNConfigCredentials?.passwordStrategy {
        case nil:
            beginVPNConfigConnectionFlow(
                with: nil,
                shouldDisableVPNOnError: true,
                shouldAskForPasswordOnReconnect: false)
        case .useSavedPassword(let password):
            // swiftlint:disable:next force_unwrapping
            let userName = openVPNConfigCredentials!.userName
            beginVPNConfigConnectionFlow(
                with: Credentials(userName: userName, password: password),
                shouldDisableVPNOnError: true,
                shouldAskForPasswordOnReconnect: false)
        #if os(macOS)
        case .askForPasswordWhenConnecting:
            let promptCredentials = Credentials(
                userName: openVPNConfigCredentials?.userName ?? "",
                password: "")
            promptForConnectionTimeVPNConfigPassword(credentials: promptCredentials)
            return
        #endif
        }
    }

    private func beginVPNConfigConnectionFlow(
        with credentials: Credentials?,
        shouldDisableVPNOnError: Bool,
        shouldAskForPasswordOnReconnect: Bool) {

        firstly { () -> Promise<Void> in
            return viewModel.beginVPNConfigConnectionFlow(
                credentials: credentials,
                shouldDisableVPNOnError: shouldDisableVPNOnError,
                shouldAskForPasswordOnReconnect: shouldAskForPasswordOnReconnect)
        }.catch { error in
            os_log("Error starting VPN config connection flow: %{public}@",
                   log: Log.general, type: .error,
                   error.localizedDescription)
            self.showAlert(for: error)
        }
    }

    #if os(macOS)
    func promptForConnectionTimeVPNConfigPassword(credentials: Credentials) {
        guard let vpnConfigInstance = parameters.connectableInstance as? VPNConfigInstance else {
            return
        }
        guard self.presentedPasswordEntryVC == nil else {
            return
        }
        let environment = parameters.environment
        let passwordEntryVC = environment.instantiatePasswordEntryViewController(
            configName: vpnConfigInstance.name,
            userName: credentials.userName,
            initialPassword: credentials.password)
        passwordEntryVC.delegate = self
        NSApp.activate(ignoringOtherApps: true)
        environment.navigationController?.presentAsSheet(passwordEntryVC)
        self.presentedPasswordEntryVC = passwordEntryVC
    }
    #endif

    private func showAlert(for error: Error) {
        if let appError = error as? AppError {
            // If there's an error getting profile config, offer to refresh profiles

            var isProfileConfigError = false
            if let serverAPIError = appError as? ServerAPIv2Error,
               case ServerAPIv2Error.errorGettingProfileConfig = serverAPIError {
                isProfileConfigError = true
            }
            if let serverAPIError = appError as? ServerAPIv3Error,
               case ServerAPIv3Error.errorGettingProfileConfig = serverAPIError {
                isProfileConfigError = true
            }

            if isProfileConfigError {
                #if os(macOS)

                let alert = NSAlert()
                alert.alertStyle = .warning
                alert.messageText = appError.summary
                alert.informativeText = appError.detail
                alert.addButton(withTitle: NSLocalizedString("Refresh Profiles", comment: "button title"))
                alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "button title"))
                if let window = self.view.window {
                    alert.beginSheetModal(for: window) { result in
                        if case .alertFirstButtonReturn = result {
                            self.beginServerConnectionFlow(continuationPolicy: .continueWithSingleOrLastUsedProfile)
                        }
                    }
                }

                #elseif os(iOS)

                let alert = UIAlertController()
                let refreshAction = UIAlertAction(
                    title: NSLocalizedString("Refresh Profiles", comment: "button title"),
                    style: .default,
                    handler: { _ in
                        self.beginServerConnectionFlow(continuationPolicy: .continueWithSingleOrLastUsedProfile)
                    })
                let cancelAction = UIAlertAction(
                    title: NSLocalizedString("Cancel", comment: "button title"),
                    style: .cancel)
                alert.addAction(refreshAction)
                alert.addAction(cancelAction)
                present(alert, animated: true, completion: nil)

                #endif
                return
            }
        }
        if !self.parameters.environment.serverAuthService.isUserCancelledError(error) {
            self.parameters.environment.navigationController?.showAlert(for: error)
        }
    }

}

extension ConnectionViewController: ConnectionViewModelDelegate {

    func connectionViewModel(
        _ model: ConnectionViewModel, foundProfiles profiles: [Profile]) {
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
        willAttemptToConnect connectionAttempt: ConnectionAttempt) {
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
        _ model: ConnectionViewModel, statusChanged status: ConnectionViewModel.ConnectionFlowStatus) {
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
        delegate?.connectionViewController(self, flowStatusChanged: status)
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
        delegate?.connectionViewController(self, isVPNTogglableBecame: vpnSwitchState.isEnabled)
    }

    func connectionViewModel(
        _ model: ConnectionViewModel,
        additionalControlChanged additionalControl: ConnectionViewModel.AdditionalControl) {
        switch additionalControl {
        case .none:
            profileSelectionView.isHidden = true
            renewSessionButton.isHidden = true
            setCredentialsButton.isHidden = true
            spinner.stopAnimation(self)
        case .spinner:
            profileSelectionView.isHidden = true
            renewSessionButton.isHidden = true
            setCredentialsButton.isHidden = true
            spinner.startAnimation(self)
        case .profileSelector(let profiles):
            profileSelectionView.isHidden = false
            renewSessionButton.isHidden = true
            setCredentialsButton.isHidden = true
            spinner.stopAnimation(self)
            #if os(macOS)
            profileSelectorPopupButton.removeAllItems()
            var selectedIndex: Int?
            for (index, profile) in profiles.enumerated() {
                let profileName = profile.displayName.stringForCurrentLanguage()
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
                profileRowNameLabel.text = selectedProfile.displayName.stringForCurrentLanguage()
            } else if let firstProfile = profiles.first {
                profileRowNameLabel.text = firstProfile.displayName.stringForCurrentLanguage()
            } else {
                profileRowNameLabel.text = NSLocalizedString("Unknown", comment: "Unknown profile")
            }
            #endif
            self.profiles = profiles
        case .renewSessionButton:
            profileSelectionView.isHidden = true
            renewSessionButton.isHidden = false
            setCredentialsButton.isHidden = true
            spinner.stopAnimation(self)
        case .setCredentialsButton:
            profileSelectionView.isHidden = true
            renewSessionButton.isHidden = true
            setCredentialsButton.isHidden = false
            spinner.stopAnimation(self)
        }
    }

    static let connectionInfoHeaderHeight: CGFloat = 46
    static let connectionInfoBodyHeight: CGFloat = 120
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
    func connectionInfoStateChanged( // swiftlint:disable:this cyclomatic_complexity
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
                vpnProtocolLabel.stringValue = {
                    guard let vpnProtocol = connectionInfo.vpnProtocol else {
                        return ""
                    }
                    return "(\(vpnProtocol))"
                }()
            } else {
                profileTitleLabel.isHidden = true
                profileNameLabel.stringValue = ""
                vpnProtocolLabel.stringValue = ""
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

            if let connectionInfoVC = self.presentedConnectionInfoVC {
                connectionInfoVC.connectionInfo = connectionInfo
            } else {
                let connectionInfoVC = parameters.environment.instantiateConnectionInfoViewController(
                    connectionInfo: connectionInfo)
                connectionInfoVC.navigationItem.rightBarButtonItem = UIBarButtonItem(
                    barButtonSystemItem: .done, target: self,
                    action: #selector(connectionInfoViewControllerDoneTapped(_:)))
                let navigationVC = UINavigationController(rootViewController: connectionInfoVC)
                navigationVC.modalPresentationStyle = .pageSheet
                present(navigationVC, animated: true) { [weak self] in
                    navigationVC.presentationController?.delegate = self
                }
                self.presentedConnectionInfoVC = connectionInfoVC
            }

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
            connectionInfoChevronButton.setAccessibilityLabel(
                NSLocalizedString(
                    "Show connection info",
                    comment: "accessibility label"))
        case .expanded:
            connectionInfoChevronButton.image = Image(named: "CloseButton")
            connectionInfoHeader.isPassthroughToButtonEnabled = false
            connectionInfoChevronButton.setAccessibilityLabel(
                NSLocalizedString(
                    "Hide connection info",
                    comment: "accessibility label"))
        }
        #elseif os(iOS)
        switch connectionInfoState {
        case .hidden, .collapsed:
            if self.presentedConnectionInfoVC != nil {
                dismiss(animated: true, completion: nil)
                self.presentedConnectionInfoVC = nil
            }
        default:
            break
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

    func connectionViewModel(
        _ model: ConnectionViewModel,
        didBeginConnectingWithCredentials credentials: Credentials?,
        shouldAskForPassword: Bool) {
        #if os(macOS)
        if let credentials = credentials, shouldAskForPassword {
            self.promptForConnectionTimeVPNConfigPassword(credentials: credentials)
        }
        #endif
    }
}

#if os(iOS)
extension ConnectionViewController {
    @objc func connectionInfoViewControllerDoneTapped(_ sender: Any) {
        if self.presentedConnectionInfoVC != nil {
            dismiss(animated: true, completion: nil)
            connectionInfoViewControllerDidGetDismissedByUser()
        }
    }

    func connectionInfoViewControllerDidGetDismissedByUser() {
        if self.presentedConnectionInfoVC != nil {
            viewModel.collapseConnectionInfo()
            self.presentedConnectionInfoVC = nil
        }
    }
}

extension ConnectionViewController: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        connectionInfoViewControllerDidGetDismissedByUser()
    }
}
#endif

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

#if os(macOS)
extension ConnectionViewController: PasswordEntryViewControllerDelegate {
    func passwordEntryViewController(
        _ controller: PasswordEntryViewController, didSetCredentials credentials: Credentials) {
        presentedPasswordEntryVC = nil
        beginVPNConfigConnectionFlow(
            with: credentials, shouldDisableVPNOnError: false, shouldAskForPasswordOnReconnect: true)
    }

    func passwordEntryViewControllerDidDisableVPN(
        _ controller: PasswordEntryViewController) {
        presentedPasswordEntryVC = nil
        disableVPN()
    }
}
#endif // swiftlint:disable:this file_length
