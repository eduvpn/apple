//
//  AppCoordinator.swift
//  EduVPN
//
//  Created by Jeroen Leenarts on 08-08-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

import UIKit

/// The AppCoordinator is our first coordinator
/// In this example the AppCoordinator as a rootViewController
class AppCoordinator: RootViewCoordinator {

    // MARK: - Properties

    var childCoordinators: [Coordinator] = []

    var rootViewController: UIViewController {
        return self.navigationController
    }

    /// Window to manage
    let window: UIWindow

    private lazy var navigationController: UINavigationController = {
        let navigationController = UINavigationController()
        return navigationController
    }()

    // MARK: - Init

    public init(window: UIWindow) {
        self.window = window

        self.window.rootViewController = self.rootViewController
        self.window.makeKeyAndVisible()
    }

    // MARK: - Functions

    /// Starts the coordinator
    public func start() {
        self.showConnectionTypeViewController()
    }

    private func showConnectionTypeViewController() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let connectionTypeViewController = storyboard.instantiateViewController(withIdentifier: "connectionTypeViewController") as? ConnectionTypeViewController {
            connectionTypeViewController.delegate = self
            self.navigationController.viewControllers = [connectionTypeViewController]
        }
    }

    fileprivate func showChooseProviderTableViewController() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let chooseProviderTableViewController = storyboard.instantiateViewController(withIdentifier: "chooseProviderTableViewController") as? ChooseProviderTableViewController {
            chooseProviderTableViewController.delegate = self
            self.navigationController.pushViewController(chooseProviderTableViewController, animated: true)
        }

    }
}

extension AppCoordinator: ConnectionTypeViewControllerDelegate {
    func connectionTypeViewControllerDidSelectProviderType(connectionTypeViewController: ConnectionTypeViewController, providerType: ProviderType) {
        switch providerType {
        case .instituteAccess:
            showChooseProviderTableViewController()
        case .secureInternet:
            print("...implement me...")
        }
    }
}

extension AppCoordinator: ChooseProviderTableViewControllerDelegate {
    func chooseProviderTableViewControllerDidSelectProviderType(chooseProviderTableViewController: ChooseProviderTableViewController) {

    }

}
