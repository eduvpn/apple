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
    func profilesFound(profiles: [ProfileListResponse.Profile])
    func canGoBackChanged(canGoBack: Bool)
    func automaticallySelectingProfile(profileId: String)
    func attemptingToConnect(
        profileId: String, certificateValidityRange: ServerAPIService.CertificateValidityRange, connectionAttemptId: UUID)

    func headerChanged(_ header: ConnectionViewModel.Header)
    func supportContactChanged(_ supportContact: ConnectionViewModel.SupportContact)
    func statusChanged(_ status: ConnectionViewModel.Status)
    func statusDetailChanged(_ statusDetail: ConnectionViewModel.StatusDetail)
    func vpnSwitchStateChanged(_ vpnSwitchState: ConnectionViewModel.VPNSwitchState)
    func additionalControlChanged(_ additionalControl: ConnectionViewModel.AdditionalControl)
    func connectionInfoStateChanged(_ connectionInfoState: ConnectionViewModel.ConnectionInfoState)
}

class ConnectionViewModel {

    // Desired state of the connection screen

    struct Header {
        let serverName: String
        let flagCountryCode: String

        init(from displayInfo: ServerDisplayInfo) {
            serverName = displayInfo.serverName(for: Locale.current, isTitle: true)
            flagCountryCode = displayInfo.flagCountryCode
        }
    }

    struct SupportContact {
        let supportContact: [String]

        init(from displayInfo: ServerDisplayInfo) {
            supportContact = displayInfo.supportContact
        }
    }

    enum Status {
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
        case profileSelector([ProfileListResponse.Profile])
        case renewSessionButton
        case spinner
    }

    enum ConnectionInfoState {
        case hidden
        case collapsed
        case expanded(ConnectionInfoHelper.ConnectionInfo)
    }

    private(set) var header: Header {
        didSet { delegate?.headerChanged(header) }
    }

    private(set) var supportContact: SupportContact {
        didSet { delegate?.supportContactChanged(supportContact) }
    }

    private(set) var status: Status {
        didSet { delegate?.statusChanged(status) }
    }

    private(set) var statusDetail: StatusDetail {
        didSet { delegate?.statusDetailChanged(statusDetail) }
    }

    private(set) var vpnSwitchState: VPNSwitchState {
        didSet { delegate?.vpnSwitchStateChanged(vpnSwitchState) }
    }

    private(set) var additionalControl: AdditionalControl {
        didSet { delegate?.additionalControlChanged(additionalControl) }
    }

    private(set) var connectionInfoState: ConnectionInfoState {
        didSet { delegate?.connectionInfoStateChanged(connectionInfoState) }
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
            self.delegate?.canGoBackChanged(canGoBack: internalState == .idle)
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

    private var profiles: [ProfileListResponse.Profile]? {
        didSet {
            self.updateStatusDetail()
            self.updateVPNSwitchState()
            self.updateAdditionalControl()
            self.delegate?.profilesFound(profiles: profiles ?? [])
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

    private let serverAPIService: ServerAPIService
    private let connectionService: ConnectionService
    private let server: ServerInstance
    private let serverDisplayInfo: ServerDisplayInfo
    private let dataStore: PersistenceService.DataStore
    private var connectingProfile: ProfileListResponse.Profile?

    init(serverAPIService: ServerAPIService, connectionService: ConnectionService,
         server: ServerInstance, serverDisplayInfo: ServerDisplayInfo,
         restoredPreConnectionState: ConnectionAttempt.PreConnectionState?) {
        self.serverAPIService = serverAPIService
        self.connectionService = connectionService
        self.server = server
        self.serverDisplayInfo = serverDisplayInfo

        header = Header(from: serverDisplayInfo)
        supportContact = SupportContact(from: serverDisplayInfo)
        status = .notConnected
        statusDetail = .none
        vpnSwitchState = VPNSwitchState(isEnabled: true, isOn: false)
        additionalControl = .none
        connectionInfoState = .hidden

        dataStore = PersistenceService.DataStore(path: server.localStoragePath)
        connectionService.statusDelegate = self

        if let restoredPreConnectionState = restoredPreConnectionState {
            self.profiles = restoredPreConnectionState.profiles
            self.connectingProfile = restoredPreConnectionState.profiles.first(where: { $0.profileId == restoredPreConnectionState.selectedProfileId })
            self.certificateExpiryHelper = CertificateExpiryHelper(
                validFrom: restoredPreConnectionState.certificateValidFrom,
                expiresAt: restoredPreConnectionState.certificateExpiresAt,
                handler: { [weak self] certificateStatus in
                    self?.certificateStatus = certificateStatus
                })
            internalState = .enabledVPN
        }
    }

    func beginConnectionFlow(from viewController: AuthorizingViewController, shouldContinueIfSingleProfile: Bool) -> Promise<Void> {
        precondition(self.connectionService.isInitialized)
        precondition(self.connectionService.isVPNEnabled == false)
        return firstly { () -> Promise<([ProfileListResponse.Profile], ServerInfo)> in
            self.internalState = .gettingProfiles
            return self.serverAPIService.getAvailableProfiles(for: server, from: viewController)
        }.then { (profiles, serverInfo) -> Promise<Void> in
            self.profiles = profiles
            if profiles.count == 1 && shouldContinueIfSingleProfile {
                self.delegate?.automaticallySelectingProfile(profileId: profiles[0].profileId)
                return self.continueConnectionFlow(
                    profile: profiles[0], from: viewController,
                    serverInfo: serverInfo)
            } else {
                self.internalState = .idle
                return Promise.value(())
            }
        }.recover { error in
            self.internalState = .idle
            throw error
        }
    }

    func continueConnectionFlow(
        profile: ProfileListResponse.Profile,
        from viewController: AuthorizingViewController,
        serverInfo: ServerInfo? = nil,
        serverAPIOptions: ServerAPIService.Options = []) -> Promise<Void> {
        precondition(self.connectionService.isInitialized)

        return firstly { () -> Promise<ServerAPIService.TunnelConfigurationData> in
            self.internalState = .configuring
            self.connectingProfile = profile
            return self.serverAPIService.getTunnelConfigurationData(
                for: server, serverInfo: serverInfo, profile: profile, from: viewController)
        }.then { tunnelConfigData -> Promise<Void> in
            self.internalState = .enableVPNRequested
            self.certificateExpiryHelper = CertificateExpiryHelper(
                validFrom: tunnelConfigData.certificateValidityRange.validFrom,
                expiresAt: tunnelConfigData.certificateValidityRange.expiresAt,
                handler: { [weak self] certificateStatus in
                    self?.certificateStatus = certificateStatus
                })
            let connectionAttemptId = UUID()
            self.delegate?.attemptingToConnect(
                profileId: profile.profileId,
                certificateValidityRange: tunnelConfigData.certificateValidityRange,
                connectionAttemptId: connectionAttemptId)
            return self.connectionService.enableVPN(
                openVPNConfig: tunnelConfigData.openVPNConfiguration,
                connectionAttemptId: connectionAttemptId)
        }.ensure {
            self.internalState = self.connectionService.isVPNEnabled ? .enabledVPN : .idle
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
        }.ensure {
            self.internalState = self.connectionService.isVPNEnabled ? .enabledVPN : .idle
            if self.internalState == .idle {
                self.connectingProfile = nil
            }
        }
    }

    func toggleConnectionInfoExpanded() {
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
        } else {
            self.connectionInfoHelper = nil
            self.connectionInfo = nil
        }
    }
}

private extension ConnectionViewModel {
    func updateStatus() {
        status = { () -> Status in
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
            if internalState == .idle && (profiles?.count ?? 0) == 0 {
                return .noProfilesAvailable
            }
            if let certificateStatus = certificateStatus {
                if certificateStatus == .expired || connectionStatus == .connected {
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
            if certificateStatus?.shouldShowRenewSessionButton ?? false {
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
    func connectionStatusChanged(status: NEVPNStatus) {
        connectionStatus = status
        if status == .connected {
            connectionInfoHelper?.refreshNetworkAddress()
        }
        if status == .disconnected {
            connectionInfoHelper = nil
            connectionInfo = nil
        }
    }
}
