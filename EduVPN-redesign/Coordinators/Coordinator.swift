//
//  Coordinator.swift
//  eduVPN
//

import Foundation

/// The Coordinator protocol
protocol Coordinator: class {

    /// Starts the coordinator
    func start()

    /// The array containing any child Coordinators
    var childCoordinators: [Coordinator] { get set }
    
    /// Provides way to inject services 
    var environment: Environment { get }
}

extension Coordinator {

    /// Add a child coordinator to the parent
    func addChildCoordinator(_ childCoordinator: Coordinator) {
        self.childCoordinators.append(childCoordinator)
    }

    /// Remove a child coordinator from the parent
    func removeChildCoordinator(_ childCoordinator: Coordinator) {
        self.childCoordinators = self.childCoordinators.filter { $0 !== childCoordinator }
    }
}
