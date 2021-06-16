//
//  ConnectionViewModel.swift
//  EduVPN
//
//  Created by Johan Kool on 28/05/2020.
//

import Foundation
import PromiseKit
import NetworkExtension

protocol ConnectionViewModelDelegate: class {
    func connectionViewModel(
        _ model: ConnectionViewModel,
        foundProfiles profiles: [Profile])
    func connectionViewModel(
        _ model: ConnectionViewModel,
        canGoBackChanged canGoBack: Bool)
    func connectionViewModel(
        _ model: ConnectionViewModel,
        willAutomaticallySelectProfileId profileId: String)
    func connectionViewModel(
        _ model: ConnectionViewModel,
        willAttemptToConnect: ConnectionAttempt)

    func connectionViewModel(
        _ model: ConnectionViewModel,
        headerChanged header: ConnectionViewModel.Header)
    func connectionViewModel(
        _ model: ConnectionViewModel,
        statusChanged status: ConnectionViewModel.ConnectionFlowStatus)
    func connectionViewModel(
        _ model: ConnectionViewModel,
        statusDetailChanged statusDetail: ConnectionViewModel.StatusDetail)
    func connectionViewModel(
        _ model: ConnectionViewModel,
        vpnSwitchStateChanged vpnSwitchState: ConnectionViewModel.VPNSwitchState)
    func connectionViewModel(
        _ model: ConnectionViewModel,
        additionalControlChanged additionalControl: ConnectionViewModel.AdditionalControl)
    func connectionViewModel(
        _ model: ConnectionViewModel,
        connectionInfoStateChanged connectionInfoState: ConnectionViewModel.ConnectionInfoState)

    func connectionViewModel(
        _ model: ConnectionViewModel,
        didBeginConnectingWithCredentials credentials: Credentials?, shouldAskForPassword: Bool)
}

class ConnectionViewModel { // swiftlint:disable:this type_body_length

    // Desired state of the connection screen

    struct Header {
        let serverName: String
        let flagCountryCode: String

        init(from displayInfo: ServerDisplayInfo) {
            serverName = displayInfo.serverName(isTitle: true)
            flagCountryCode = displayInfo.flagCountryCode
        }
    }

    struct SupportContact {
        let supportContact: [String]

        init(from displayInfo: ServerDisplayInfo) {
            supportContact = displayInfo.supportContact
        }
    }

    enum ConnectionFlowStatus {
        case notConnected
        case gettingProfiles
        case configuring
        case connecting
        case connected
        case disconnecting
        case reconnecting
    }

    enum StatusDetail {
        case none
        case sessionStatus(CertificateExpiryHelper.CertificateStatus)
        case noProfilesAvailable
    }

    struct VPNSwitchState {
        let isEnabled: Bool
        let isOn: Bool
    }

    enum AdditionalControl {
        case none
        case profileSelector([Profile])
        case renewSessionButton
        case setCredentialsButton
        case spinner
    }

    enum ConnectionInfoState {
        case hidden
        case collapsed
        case expanded(ConnectionInfoHelper.ConnectionInfo)
    }

    private(set) var header: Header {
        didSet { delegate?.connectionViewModel(self, headerChanged: header) }
    }

    private(set) var supportContact: SupportContact

    private(set) var status: ConnectionFlowStatus {
        didSet { delegate?.connectionViewModel(self, statusChanged: status) }
    }

    private(set) var statusDetail: StatusDetail {
        didSet { delegate?.connectionViewModel(self, statusDetailChanged: statusDetail) }
    }

    private(set) var vpnSwitchState: VPNSwitchState {
        didSet { delegate?.connectionViewModel(self, vpnSwitchStateChanged: vpnSwitchState) }
    }

    private(set) var additionalControl: AdditionalControl {
        didSet { delegate?.connectionViewModel(self, additionalControlChanged: additionalControl) }
    }

    private(set) var connectionInfoState: ConnectionInfoState {
        didSet { delegate?.connectionViewModel(self, connectionInfoStateChanged: connectionInfoState) }
    }

    var canGoBack: Bool { internalState == .idle }

    // State of the connection view model

    private enum InternalState: Equatable {
        case idle
        case gettingProfiles
        case configuring
        case enableVPNRequested
        case disableVPNRequested
        case enabledVPN
    }

    private var internalState: InternalState = .idle {
        didSet {
            self.updateStatus()
            self.updateStatusDetail()
            self.updateVPNSwitchState()
            self.updateAdditionalControl()
            self.delegate?.connectionViewModel(self, canGoBackChanged: internalState == .idle)
        }
    }

    private var connectionStatus: NEVPNStatus = .invalid {
        didSet {
            self.updateStatus()
            self.updateStatusDetail()
            self.updateVPNSwitchState()
            self.updateAdditionalControl()
            self.updateConnectionInfoState()
        }
    }

    private var profiles: [Profile]? {
        didSet {
            self.updateStatusDetail()
            self.updateVPNSwitchState()
            self.updateAdditionalControl()
            self.delegate?.connectionViewModel(self, foundProfiles: profiles ?? [])
        }
    }

    private var certificateStatus: CertificateExpiryHelper.CertificateStatus? {
        didSet {
            self.updateStatusDetail()
            self.updateAdditionalControl()
        }
    }

    private var connectionInfo: ConnectionInfoHelper.ConnectionInfo? {
        didSet {
            self.updateConnectionInfoState()
        }
    }

    private var certificateExpiryHelper: CertificateExpiryHelper? {
        didSet {
            self.updateStatusDetail()
            self.updateAdditionalControl()
        }
    }
    private var connectionInfoHelper: ConnectionInfoHelper? {
        didSet {
            self.updateAdditionalControl()
            self.updateConnectionInfoState()
        }
    }

    weak var delegate: ConnectionViewModelDelegate?

    private let connectableInstance: ConnectableInstance
    private let connectionService: ConnectionServiceProtocol
    private let notificationService: NotificationService?
    private let serverDisplayInfo: ServerDisplayInfo

    private let serverAPIService: ServerAPIService?
    private let authURLTemplate: String?

    private let dataStore: PersistenceService.DataStore
    private var connectingProfile: Profile?

    private var vpnConfigCredentials: Credentials?
    private var shouldAskForPasswordOnReconnect: Bool = false
    private var isBeginningVPNConfigConnectionFlow: Bool = false

    init(server: ServerInstance,
         connectionService: ConnectionServiceProtocol,
         notificationService: NotificationService,
         serverDisplayInfo: ServerDisplayInfo,
         serverAPIService: ServerAPIService,
         authURLTemplate: String?,
         restoringPreConnectionState: ConnectionAttempt.ServerPreConnectionState?) {

        self.connectableInstance = server
        self.connectionService = connectionService
        self.notificationService = notificationService
        self.serverDisplayInfo = serverDisplayInfo
        self.serverAPIService = serverAPIService
        self.authURLTemplate = authURLTemplate

        header = Header(from: serverDisplayInfo)
        supportContact = SupportContact(from: serverDisplayInfo)
        status = .notConnected
        statusDetail = .none
        vpnSwitchState = VPNSwitchState(isEnabled: true, isOn: false)
        additionalControl = .none
        connectionInfoState = .hidden

        dataStore = PersistenceService.DataStore(path: server.localStoragePath)
        connectionService.statusDelegate = self

        if let preConnectionState = restoringPreConnectionState {
            profiles = preConnectionState.profiles
            connectingProfile = preConnectionState.profiles
                .first(where: { $0.profileId == preConnectionState.selectedProfileId })
            certificateExpiryHelper = CertificateExpiryHelper(
                expiresAt: preConnectionState.sessionExpiresAt,
                handler: { [weak self] certificateStatus in
                    self?.certificateStatus = certificateStatus
                })
            internalState = .enabledVPN
        }
    }

    init(vpnConfigInstance: VPNConfigInstance,
         connectionService: ConnectionServiceProtocol,
         serverDisplayInfo: ServerDisplayInfo,
         restoringPreConnectionState: ConnectionAttempt.VPNConfigPreConnectionState?) {

        self.connectableInstance = vpnConfigInstance
        self.connectionService = connectionService
        self.notificationService = nil
        self.serverDisplayInfo = serverDisplayInfo
        self.serverAPIService = nil
        self.authURLTemplate = nil

        header = Header(from: serverDisplayInfo)
        supportContact = SupportContact(from: serverDisplayInfo)
        status = .notConnected
        statusDetail = .none
        vpnSwitchState = VPNSwitchState(isEnabled: true, isOn: false)
        additionalControl = .none
        connectionInfoState = .hidden

        dataStore = PersistenceService.DataStore(path: vpnConfigInstance.localStoragePath)
        connectionService.statusDelegate = self

        if let preConnectionState = restoringPreConnectionState {
            shouldAskForPasswordOnReconnect = preConnectionState.shouldAskForPasswordOnReconnect
            internalState = .enabledVPN
            let dataStore = PersistenceService.DataStore(path: vpnConfigInstance.localStoragePath)
            let openVPNConfigCredentials = dataStore.openVPNConfigCredentials
            vpnConfigCredentials = Credentials(userName: openVPNConfigCredentials?.userName ?? "", password: "")
        }
    }

    func beginServerConnectionFlow(
        from viewController: AuthorizingViewController,
        continuationPolicy: ServerConnectionFlowContinuationPolicy,
        preferredProfileId: String?) -> Promise<Void> {
        precondition(self.connectionService.isInitialized)
        precondition(self.connectionService.isVPNEnabled == false)
        guard let server = connectableInstance as? ServerInstance,
              let serverAPIService = serverAPIService else {
            return Promise.value(())
        }
        return firstly { () -> Promise<([Profile], ServerInfo)> in
            self.internalState = .gettingProfiles
            return serverAPIService.getAvailableProfiles(
                for: server, from: viewController,
                wayfSkippingInfo: wayfSkippingInfo(), options: [])
        }.then { (profiles, serverInfo) -> Promise<Void> in
            self.profiles = profiles
            switch continuationPolicy {
            case .continueIfOnlyOneProfileFound:
                guard profiles.count == 1 else {
                    self.internalState = .idle
                    return Promise.value(())
                }
                self.delegate?.connectionViewModel(self, willAutomaticallySelectProfileId: profiles[0].profileId)
                return self.continueServerConnectionFlow(
                    profile: profiles[0], from: viewController,
                    serverInfo: serverInfo)
            case .continueIfAnyProfileFound:
                guard let firstProfile = profiles.first else {
                    self.internalState = .idle
                    return Promise.value(())
                }
                let profile: Profile = {
                    if let preferredProfileId = preferredProfileId {
                        return profiles.first(where: { $0.profileId == preferredProfileId }) ?? firstProfile
                    } else {
                        return firstProfile
                    }
                }()
                self.delegate?.connectionViewModel(self, willAutomaticallySelectProfileId: profile.profileId)
                return self.continueServerConnectionFlow(
                    profile: profile, from: viewController,
                    serverInfo: serverInfo)
            case .doNotContinue, .notApplicable:
                self.internalState = .idle
                return Promise.value(())
            }
        }.recover { error in
            self.internalState = .idle
            throw error
        }
    }

    // swiftlint:disable:next function_body_length
    func continueServerConnectionFlow(
        profile: Profile,
        from viewController: AuthorizingViewController,
        serverInfo: ServerInfo? = nil,
        serverAPIOptions: ServerAPIService.Options = []) -> Promise<Void> {
        precondition(self.connectionService.isInitialized)

        guard let server = connectableInstance as? ServerInstance,
              let serverAPIService = serverAPIService else {
            return Promise.value(())
        }

        return firstly { () -> Promise<ServerAPIService.TunnelConfigurationData> in
            self.internalState = .configuring
            self.connectingProfile = profile
            return serverAPIService.getTunnelConfigurationData(
                for: server, serverInfo: serverInfo, profile: profile,
                from: viewController, wayfSkippingInfo: wayfSkippingInfo(),
                options: serverAPIOptions)
        }.then { tunnelConfigData -> Promise<(Date, UUID)> in
            self.internalState = .enableVPNRequested
            let expiresAt = tunnelConfigData.certificateValidityRange.expiresAt
            self.certificateExpiryHelper = CertificateExpiryHelper(
                expiresAt: expiresAt,
                handler: { [weak self] certificateStatus in
                    self?.certificateStatus = certificateStatus
                })
            let connectionAttemptId = UUID()
            let connectionAttempt = ConnectionAttempt(
                server: server,
                profiles: self.profiles ?? [],
                selectedProfileId: profile.profileId,
                sessionExpiresAt: tunnelConfigData.expiresAt,
                attemptId: connectionAttemptId)
            self.delegate?.connectionViewModel(self, willAttemptToConnect: connectionAttempt)
            switch tunnelConfigData.vpnConfig {
            case .openVPNConfig(let configLines):
                return self.connectionService.enableVPN(
                    openVPNConfig: configLines,
                    connectionAttemptId: connectionAttemptId,
                    credentials: nil,
                    shouldDisableVPNOnError: true,
                    shouldPreventAutomaticConnections: false)
                    .map { (expiresAt, connectionAttemptId) }
            default:
                fatalError("WireGuard profiles not supported yet")
            }
        }.then { (expiresAt, connectionAttemptId) -> Promise<Void> in
            self.internalState = self.connectionService.isVPNEnabled ? .enabledVPN : .idle
            guard let notificationService = self.notificationService else {
                return Promise.value(())
            }
            return notificationService.attemptSchedulingSessionExpiryNotification(
                expiryDate: expiresAt, connectionAttemptId: connectionAttemptId, from: viewController)
                .map { _ in }
        }.ensure {
            self.internalState = self.connectionService.isVPNEnabled ? .enabledVPN : .idle
        }
    }

    func beginVPNConfigConnectionFlow(
        credentials: Credentials?,
        shouldDisableVPNOnError: Bool,
        shouldAskForPasswordOnReconnect: Bool) -> Promise<Void> {

        precondition(self.connectionService.isInitialized)
        #if os(iOS)
        precondition(shouldAskForPasswordOnReconnect == false)
        #endif
        guard let vpnConfigInstance = connectableInstance as? VPNConfigInstance else {
            return Promise.value(())
        }
        let connectionAttemptId = UUID()
        let connectionAttempt = ConnectionAttempt(
            vpnConfigInstance: vpnConfigInstance,
            shouldAskForPasswordOnReconnect: shouldAskForPasswordOnReconnect,
            attemptId: connectionAttemptId)
        let dataStore = PersistenceService.DataStore(path: vpnConfigInstance.localStoragePath)
        guard let vpnConfigString = dataStore.vpnConfig else {
            return Promise.value(())
        }
        let vpnConfigLines = vpnConfigString.components(separatedBy: .newlines)
        self.internalState = .enableVPNRequested
        self.shouldAskForPasswordOnReconnect = true
        self.isBeginningVPNConfigConnectionFlow = true

        return firstly { () -> Promise<Void> in
            self.delegate?.connectionViewModel(self, willAttemptToConnect: connectionAttempt)
            return self.connectionService.enableVPN(
                openVPNConfig: vpnConfigLines,
                connectionAttemptId: connectionAttemptId,
                credentials: credentials,
                shouldDisableVPNOnError: shouldDisableVPNOnError,
                shouldPreventAutomaticConnections: shouldAskForPasswordOnReconnect)
        }.ensure {
            self.internalState = self.connectionService.isVPNEnabled ? .enabledVPN : .idle
            self.vpnConfigCredentials = credentials
            self.isBeginningVPNConfigConnectionFlow = false
        }
    }

    func disableVPN() -> Promise<Void> {
        precondition(self.connectionService.isInitialized)
        guard self.connectionService.isVPNEnabled == true else {
            return Promise.value(())
        }
        return firstly { () -> Promise<Void> in
            self.internalState = .disableVPNRequested
            return self.connectionService.disableVPN()
        }.map {
            self.notificationService?.descheduleSessionExpiryNotification()
        }.ensure {
            self.internalState = self.connectionService.isVPNEnabled ? .enabledVPN : .idle
            if self.internalState == .idle {
                self.connectingProfile = nil
            }
        }
    }

    func toggleConnectionInfoExpanded() {
        if self.connectionInfoHelper == nil {
            expandConnectionInfo()
        } else {
            collapseConnectionInfo()
        }
    }

    func expandConnectionInfo() {
        if self.connectionInfoHelper == nil {
            let connectionStatus = self.connectionService.connectionStatus
            guard connectionStatus == .connected || connectionStatus == .reasserting else {
                return
            }
            let connectionInfoHelper = ConnectionInfoHelper(
                connectionService: self.connectionService,
                profileName: connectingProfile?.displayName,
                handler: { [weak self] connectionInfo in
                    self?.connectionInfo = connectionInfo
                })
            connectionInfoHelper.startUpdating()
            self.connectionInfoHelper = connectionInfoHelper
        }
    }

    func collapseConnectionInfo() {
        self.connectionInfoHelper = nil
        self.connectionInfo = nil
    }

    func scheduleSessionExpiryNotificationOnActiveVPN() -> Guarantee<Bool> {
        guard connectionService.isInitialized else { return Guarantee<Bool>.value(false) }
        guard connectionService.isVPNEnabled else { return Guarantee<Bool>.value(false) }
        guard connectableInstance is ServerInstance else { return Guarantee<Bool>.value(false) }
        if let connectionAttemptId = connectionService.connectionAttemptId,
           let expiryDate = certificateExpiryHelper?.expiresAt,
           let notificationService = notificationService {
            return notificationService.scheduleSessionExpiryNotification(
                expiryDate: expiryDate, connectionAttemptId: connectionAttemptId)
        }
        return Guarantee<Bool>.value(false)
    }
}

private extension ConnectionViewModel {
    private func wayfSkippingInfo() -> ServerAuthService.WAYFSkippingInfo? {
        if let secureInternetServer = connectableInstance as? SecureInternetServerInstance,
            let authURLTemplate = self.authURLTemplate {
            return ServerAuthService.WAYFSkippingInfo(
                authURLTemplate: authURLTemplate, orgId: secureInternetServer.orgId)
        }
        return nil
    }
}

private extension ConnectionViewModel {
    func updateStatus() {
        status = { () -> ConnectionFlowStatus in
            switch (internalState, connectionStatus) {
            case (.gettingProfiles, _): return .gettingProfiles
            case (.configuring, _): return .configuring
            case (.enableVPNRequested, .invalid),
                 (.enableVPNRequested, .disconnected):
                return .configuring
            case (_, .invalid),
                 (_, .disconnected):
                return .notConnected
            case (_, .connecting): return .connecting
            case (_, .connected): return .connected
            case (_, .reasserting): return .reconnecting
            case (_, .disconnecting): return .disconnecting
            case (_, _): return .notConnected
            }
        }()
    }

    func updateStatusDetail() {
        statusDetail = { () -> StatusDetail in
            if internalState == .gettingProfiles || internalState == .configuring {
                return .none
            }
            if (connectableInstance is ServerInstance) &&
                    (internalState == .idle) && (profiles?.count ?? 0) == 0 {
                return .noProfilesAvailable
            }
            if internalState == .enabledVPN {
                if let certificateStatus = certificateStatus {
                    return .sessionStatus(certificateStatus)
                }
            }
            return .none
        }()
    }

    func updateVPNSwitchState() {
        vpnSwitchState = { () -> VPNSwitchState in
            let isSwitchEnabled = (internalState == .idle || internalState == .enabledVPN ||
                connectionStatus == .connecting)
            let isSwitchOn = { () -> Bool in
                switch self.internalState {
                case .configuring, .enableVPNRequested: return true
                case .disableVPNRequested: return false
                default: return self.connectionService.isVPNEnabled
                }
            }()
            return VPNSwitchState(isEnabled: isSwitchEnabled, isOn: isSwitchOn)
        }()
    }

    func updateAdditionalControl() {
        additionalControl = { () -> AdditionalControl in
            if connectionInfoHelper != nil {
                // Make space for the expanded connection info
                return .none
            }
            if internalState == .gettingProfiles || internalState == .configuring {
                return .spinner
            }
            if (certificateStatus?.shouldShowRenewSessionButton ?? false) && internalState == .enabledVPN {
                return .renewSessionButton
            }
            if internalState == .idle, let profiles = profiles, profiles.count > 1 {
                return .profileSelector(profiles)
            }
            if connectionStatus == .connecting ||
                connectionStatus == .disconnecting ||
                connectionStatus == .reasserting {
                return .spinner
            }
            if connectionStatus == .disconnected && connectableInstance is VPNConfigInstance {
                return .setCredentialsButton
            }
            return .none
        }()
    }

    func updateConnectionInfoState() {
        connectionInfoState = { () -> ConnectionInfoState in
            guard connectionStatus == .connected || connectionStatus == .reasserting else {
                return .hidden
            }
            if connectionInfoHelper != nil {
                if let connectionInfo = connectionInfo {
                    return .expanded(connectionInfo)
                }
            }
            return .collapsed
        }()
    }
}

extension ConnectionViewModel: ConnectionServiceStatusDelegate {
    func connectionService(_ service: ConnectionServiceProtocol, connectionStatusChanged status: NEVPNStatus) {
        connectionStatus = status
        if status == .connected {
            connectionInfoHelper?.refreshNetworkAddress()
        }
        if status == .disconnected {
            connectionInfoHelper = nil
            connectionInfo = nil
        }
        if status == .connecting {
            let shouldAskForPassword = shouldAskForPasswordOnReconnect && !isBeginningVPNConfigConnectionFlow
            self.delegate?.connectionViewModel(
                self,
                didBeginConnectingWithCredentials: vpnConfigCredentials,
                shouldAskForPassword: shouldAskForPassword)
        }
    }
} // swiftlint:disable:this file_length
