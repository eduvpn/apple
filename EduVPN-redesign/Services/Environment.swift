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
    let serverApiService: ServerApiServiceType
    let tunnelService: TunnelServiceType

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
        
        let serverApiService = ServerApiService()
        self.serverApiService = serverApiService
        self.tunnelService = TunnelService(serverApiService: serverApiService)
    }

    func instantiateSearchViewController() -> SearchViewController {
        let parameters = SearchViewController.Parameters(environment: self)
        return instantiate(SearchViewController.self, identifier: "Search", parameters: parameters)
    }

    func instantiate<VC: ParametrizedViewController>(_ type: VC.Type, identifier: String,
                                                     parameters: VC.Parameters) -> VC {
        // In macOS 10.15 / iOS 13 and later, we can pass our own parameters to
        // view controllers when instantiating them using creator blocks.
        // Since we have to support earlier OS versions, we inject the parameters
        // by calling 'initializeParameters'.

        guard let viewController =
            storyboard.instantiateViewController(withIdentifier: identifier) as? VC else {
                fatalError("Can't instantiate view controller with identifier: \(identifier)")
        }
        viewController.initializeParameters(parameters)
        return viewController
    }
}
