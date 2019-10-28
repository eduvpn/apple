//
//  Coordinator.swift
//  eduVPN
//
//  Created by Jeroen Leenarts on 08-08-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

import Foundation

/// The Coordinator protocol
public protocol Coordinator: class {

    /// Starts the coordinator
    func start()

    /// The array containing any child Coordinators
    var childCoordinators: [Coordinator] { get set }
}

public extension Coordinator {

    /// Add a child coordinator to the parent
    func addChildCoordinator(_ childCoordinator: Coordinator) {
        self.childCoordinators.append(childCoordinator)
    }

    /// Remove a child coordinator from the parent
    func removeChildCoordinator(_ childCoordinator: Coordinator) {
        self.childCoordinators = self.childCoordinators.filter { $0 !== childCoordinator }
    }
}
