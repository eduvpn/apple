//
//  Environment.swift
//  eduVPN 2
//
//  Created by Johan Kool on 28/05/2020.
//

import Foundation

protocol ParametrizedViewController: ViewController {
    associatedtype Parameters
    func initializeParameters(_: Parameters)
}

class Environment {
    private lazy var storyboard = Storyboard(name: "Main", bundle: nil)
    weak var navigationController: NavigationController?

    let serverDiscoveryService: ServerDiscoveryService?
    let serverAuthService: ServerAuthService
    let persistenceService: PersistenceService
    let serverAPIService: ServerAPIService
    let notificationService: NotificationService
    let connectionService: ConnectionServiceProtocol
    let loggingService: LoggingService

    init(navigationController: NavigationController) {
        self.navigationController = navigationController
        let isDiscoveryEnabled = Config.shared.apiDiscoveryEnabled ?? false
        if isDiscoveryEnabled,
           let discoveryConfig = Config.shared.discovery {
            self.serverDiscoveryService = ServerDiscoveryService(discoveryConfig: discoveryConfig)
        } else {
            self.serverDiscoveryService = nil
        }
        self.serverAuthService = ServerAuthService(
            configRedirectURL: Config.shared.redirectUrl,
            configClientId: Config.shared.clientId)
        self.persistenceService = PersistenceService()
        self.serverAPIService = ServerAPIService(serverAuthService: serverAuthService)
        self.notificationService = NotificationService()

        #if targetEnvironment(simulator)
        let connectionService = MockConnectionService()
        #else
        let connectionService = ConnectionService()
        #endif
        self.connectionService = connectionService

        self.loggingService = LoggingService(connectionService: connectionService)
    }

    func instantiateSearchViewController(
        shouldIncludeOrganizations: Bool, shouldAutoFocusSearchField: Bool) -> SearchViewController {
        let parameters = SearchViewController.Parameters(
            environment: self,
            shouldIncludeOrganizations: shouldIncludeOrganizations,
            shouldAutoFocusSearchField: shouldAutoFocusSearchField)
        return instantiate(SearchViewController.self, identifier: "Search", parameters: parameters)
    }

    func instantiateAddServerViewController(
        predefinedProvider: PredefinedProvider?, shouldAutoFocusURLField: Bool) -> AddServerViewController {
        let parameters = AddServerViewController.Parameters(
            environment: self,
            predefinedProvider: predefinedProvider,
            shouldAutoFocusURLField: shouldAutoFocusURLField)
        return instantiate(AddServerViewController.self, identifier: "AddServer", parameters: parameters)
    }

    func instantiateConnectionViewController(
        connectableInstance: ConnectableInstance, serverDisplayInfo: ServerDisplayInfo,
        initialConnectionFlowContinuationPolicy: ConnectionViewModel.FlowContinuationPolicy,
        authURLTemplate: String? = nil,
        restoringPreConnectionState: ConnectionAttempt.PreConnectionState? = nil) -> ConnectionViewController {
        let parameters = ConnectionViewController.Parameters(
            environment: self, connectableInstance: connectableInstance, serverDisplayInfo: serverDisplayInfo,
            authURLTemplate: authURLTemplate,
            initialConnectionFlowContinuationPolicy: initialConnectionFlowContinuationPolicy,
            restoringPreConnectionState: restoringPreConnectionState)
        return instantiate(ConnectionViewController.self, identifier: "Connection", parameters: parameters)
    }

    func instantiateCredentialsViewController(
        initialCredentials: OpenVPNConfigCredentials?) -> CredentialsViewController {
        let parameters = CredentialsViewController.Parameters(
            initialCredentials: initialCredentials)
        return instantiate(CredentialsViewController.self, identifier: "Credentials", parameters: parameters)
    }

    #if os(macOS)
    func instantiatePreferencesViewController(mainVC: MainViewController) -> PreferencesViewController {
        let parameters = PreferencesViewController.Parameters(environment: self, mainVC: mainVC)
        return instantiate(PreferencesViewController.self, identifier: "Preferences", parameters: parameters)
    }

    func instantiatePasswordEntryViewController(
        configName: String, userName: String, initialPassword: String) -> PasswordEntryViewController {
        let parameters = PasswordEntryViewController.Parameters(
            configName: configName, userName: userName, initialPassword: initialPassword)
        return instantiate(PasswordEntryViewController.self, identifier: "PasswordEntry", parameters: parameters)
    }
    #endif

    #if os(iOS)
    func instantiateItemSelectionViewController(
        items: [ItemSelectionViewController.Item], selectedIndex: Int) -> ItemSelectionViewController {
        let parameters = ItemSelectionViewController.Parameters(
            items: items, selectedIndex: selectedIndex)
        return instantiate(ItemSelectionViewController.self, identifier: "ItemSelection", parameters: parameters)
    }

    func instantiateConnectionInfoViewController(
        connectionInfo: ConnectionInfoHelper.ConnectionInfo) -> ConnectionInfoViewController {
        let parameters = ConnectionInfoViewController.Parameters(
            connectionInfo: connectionInfo)
        return instantiate(ConnectionInfoViewController.self, identifier: "ConnectionInfo", parameters: parameters)
    }

    func instantiateSettingsViewController(mainVC: MainViewController) -> SettingsViewController {
        let parameters = SettingsViewController.Parameters(environment: self, mainVC: mainVC)
        return instantiate(SettingsViewController.self, identifier: "Settings", parameters: parameters)
    }

    func instantiateLogViewController() -> LogViewController {
        let parameters = LogViewController.Parameters(environment: self)
        return instantiate(LogViewController.self, identifier: "Log", parameters: parameters)
    }
    #endif

    func instantiate<VC: ViewController>(_ type: VC.Type, identifier: String) -> VC {
        guard let viewController =
            storyboard.instantiateViewController(withIdentifier: identifier) as? VC else {
                fatalError("Can't instantiate view controller with identifier: \(identifier)")
        }
        return viewController
    }

    func instantiate<VC: ParametrizedViewController>(_ type: VC.Type, identifier: String,
                                                     parameters: VC.Parameters) -> VC {
        // In macOS 10.15 / iOS 13 and later, we can pass our own parameters to
        // view controllers when instantiating them using creator blocks.
        // Since we have to support earlier OS versions, we inject the parameters
        // by calling 'initializeParameters'.

        let viewController = instantiate(type, identifier: identifier)
        viewController.initializeParameters(parameters)
        return viewController
    }
}
