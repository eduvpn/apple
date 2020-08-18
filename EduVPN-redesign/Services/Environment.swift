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
    let connectionService: ConnectionService

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
        self.connectionService = ConnectionService()
    }

    func instantiateSearchViewController(shouldIncludeOrganizations: Bool) -> SearchViewController {
        let parameters = SearchViewController.Parameters(
            environment: self,
            shouldIncludeOrganizations: shouldIncludeOrganizations)
        return instantiate(SearchViewController.self, identifier: "Search", parameters: parameters)
    }

    func instantiateConnectionViewController(
        server: ServerInstance, serverDisplayInfo: ServerDisplayInfo,
        restoredPreConnectionState: ConnectionAttempt.PreConnectionState? = nil) -> ConnectionViewController {
        let parameters = ConnectionViewController.Parameters(
            environment: self, server: server, serverDisplayInfo: serverDisplayInfo,
            restoredPreConnectionState: restoredPreConnectionState)
        return instantiate(ConnectionViewController.self, identifier: "Connection", parameters: parameters)
    }

    func instantiatePreferencesViewController() -> PreferencesViewController {
        return instantiate(PreferencesViewController.self, identifier: "Preferences")
    }

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
