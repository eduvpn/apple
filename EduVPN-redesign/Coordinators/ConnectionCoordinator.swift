//
//  ConnectionCoordinator.swift
//  EduVPN
//
//  Created by Johan Kool on 28/05/2020.
//

import Foundation

protocol ConnectionCoordinatorDelegate: class {
    func connectionCoordinatorDidFinish(_ coordinator: ConnectionCoordinator)
}

class ConnectionCoordinator: Coordinator {
    
    var presentingViewController: NavigationController
    weak var delegate: ConnectionCoordinatorDelegate?
    var childCoordinators: [Coordinator] = []
    let environment: Environment
    
    init(presentingViewController: NavigationController, delegate: ConnectionCoordinatorDelegate, environment: Environment) {
        self.presentingViewController = presentingViewController
        self.delegate = delegate
        self.environment = environment
    }
    
    func start() {
        guard let connectionViewController = environment.storyboard.instantiateViewController(withIdentifier: "Connection") as? ConnectionViewController else {
            return
        }
        connectionViewController.viewModel = ConnectionViewModel(environment: environment)
        connectionViewController.delegate = self
        presentingViewController.pushViewController(connectionViewController, animated: true)
    }
    
}

extension ConnectionCoordinator: ConnectionViewControllerDelegate {
    
    func connectionViewControllerClosed(_ controller: ConnectionViewController) {
        presentingViewController.popViewController(animated: true)
        delegate?.connectionCoordinatorDidFinish(self)
    }
    
}
