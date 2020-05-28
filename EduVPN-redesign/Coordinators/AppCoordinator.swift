//
//  AppCoordinator.swift
//  EduVPN
//
//  Created by Johan Kool on 28/05/2020.
//  Copyright © 2020 SURFNet. All rights reserved.
//

import Foundation

class AppCoordinator: Coordinator {
    
    let window: Window
    var childCoordinators: [Coordinator] = []
    let environment: Environment
    
    private let rootViewController: ViewController
    
    init(window: Window, environment: Environment) {
        self.window = window
        self.environment = environment
        
        rootViewController = ViewController() // TODO: Add to window
    }
    
    func start() {
        let mainCoordinator = MainCoordinator(rootViewController: rootViewController, environment: environment)
        addChildCoordinator(mainCoordinator)
    }
    
    func showSettings() {
        let settingsViewController = SettingsViewController(viewModel: SettingsViewModel(environment: environment), delegate: self)
        //  rootViewController.present(settingsViewController, animator: )
    }
    
    func showHelp() {
        // TODO: Open Help URL
    }
    
}

extension AppCoordinator: SettingsViewControllerDelegate {
    
    func settingsViewControllerClosed(_ controller: SettingsViewController) {
        rootViewController.dismiss(controller)
    }
    
}
