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
    let connectionService: ConnectionServiceProtocol

    init(navigationController: NavigationController) {
        self.navigationController = navigationController
        if let discoveryConfig = Config.shared.discovery {
            self.serverDiscoveryService = ServerDiscoveryService(discoveryConfig: discoveryConfig)
        } else {
            self.serverDiscoveryService = nil
        }
        self.serverAuthService = ServerAuthService(
            configRedirectURL: Config.shared.redirectUrl,
            configClientId: Config.shared.clientId)
        self.persistenceService = PersistenceService()
        self.serverAPIService = ServerAPIService(serverAuthService: serverAuthService)
        #if targetEnvironment(simulator)
        self.connectionService = MockConnectionService()
        #else
        self.connectionService = ConnectionService()
        #endif
    }

    func instantiateSearchViewController(shouldIncludeOrganizations: Bool) -> SearchViewController {
        let parameters = SearchViewController.Parameters(
            environment: self,
            shouldIncludeOrganizations: shouldIncludeOrganizations)
        return instantiate(SearchViewController.self, identifier: "Search", parameters: parameters)
    }

    func instantiateConnectionViewController(
        server: ServerInstance, serverDisplayInfo: ServerDisplayInfo, authURLTemplate: String?,
        restoredPreConnectionState: ConnectionAttempt.PreConnectionState? = nil) -> ConnectionViewController {
        let parameters = ConnectionViewController.Parameters(
            environment: self, server: server, serverDisplayInfo: serverDisplayInfo,
            authURLTemplate: authURLTemplate,
            restoredPreConnectionState: restoredPreConnectionState)
        return instantiate(ConnectionViewController.self, identifier: "Connection", parameters: parameters)
    }

    #if os(macOS)
    func instantiatePreferencesViewController() -> PreferencesViewController {
        let parameters = PreferencesViewController.Parameters(environment: self)
        return instantiate(PreferencesViewController.self, identifier: "Preferences", parameters: parameters)
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

    func instantiateSettingsViewController() -> SettingsViewController {
        let parameters = SettingsViewController.Parameters(environment: self)
        return instantiate(SettingsViewController.self, identifier: "Settings", parameters: parameters)
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
