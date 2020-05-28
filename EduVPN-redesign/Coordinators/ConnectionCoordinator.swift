//
//  ConnectionCoordinator.swift
//  EduVPN
//
//  Created by Johan Kool on 28/05/2020.
//  Copyright © 2020 SURFNet. All rights reserved.
//

import Foundation

protocol ConnectionCoordinatorDelegate: class {
    func connectionCoordinatorDidFinish(_ coordinator: ConnectionCoordinator)
}

class ConnectionCoordinator: Coordinator {
    
    var presentingViewController: ViewController
    weak var delegate: ConnectionCoordinatorDelegate?
    var childCoordinators: [Coordinator] = []
    let environment: Environment
    
    init(presentingViewController: ViewController, delegate: ConnectionCoordinatorDelegate, environment: Environment) {
        self.presentingViewController = presentingViewController
        self.delegate = delegate
        self.environment = environment
    }
    
    func start() {
        let connectionViewController = ConnectionViewController(viewModel: ConnectionViewModel(environment: environment), delegate: self)
        // presentingViewController.push(connectionViewController) // TODO: Generic way to push
    }
    
}

extension ConnectionCoordinator: ConnectionViewControllerDelegate {
    
    func connectionViewControllerClosed(_ controller: ConnectionViewController) {
        // presentingViewController.pop() // TODO
    }
    
}
