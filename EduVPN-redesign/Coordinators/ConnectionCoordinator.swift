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
    let server: AnyObject
    
    init(presentingViewController: NavigationController, delegate: ConnectionCoordinatorDelegate, environment: Environment, server: AnyObject) {
        self.presentingViewController = presentingViewController
        self.delegate = delegate
        self.environment = environment
        self.server = server
    }
    
    func start() {
        guard let connectionViewController = environment.storyboard.instantiateViewController(withIdentifier: "Connection") as? ConnectionViewController else {
            return
        }
        connectionViewController.viewModel = ConnectionViewModel(environment: environment, server: server)
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
