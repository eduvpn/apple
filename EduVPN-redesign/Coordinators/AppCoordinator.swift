//
//  AppCoordinator.swift
//  EduVPN
//
//  Created by Johan Kool on 28/05/2020.
//

import Foundation

class AppCoordinator: Coordinator {
    
    let window: Window
    var childCoordinators: [Coordinator] = []
    let environment: Environment
    
    private let rootViewController: NavigationController
    
    init(window: Window, environment: Environment) {
        self.window = window
        self.environment = environment
        
        #if os(iOS)
        guard let rootViewController = environment.storyboard.instantiateInitialViewController() as? NavigationController else {
            fatalError("Could not create rootViewController")
        }
        window.rootViewController = rootViewController
        #elseif os(macOS)
        guard let rootViewController = window.rootViewController as? NavigationController else {
            fatalError("Could not create rootViewController")
        }
        #endif
        
        self.rootViewController = rootViewController
    }
    
    func start() {
        window.makeKeyAndVisible()
        
        let mainCoordinator = MainCoordinator(rootViewController: rootViewController, environment: environment)
        addChildCoordinator(mainCoordinator)
        mainCoordinator.start()
    }
    
    func showSettings() {
        let settingsViewController = SettingsViewController(viewModel: SettingsViewModel(environment: environment), delegate: self)
        rootViewController.present(settingsViewController, animated: true, completion: nil)
    }
    
    func showHelp() {
        // TODO: Open Help URL
    }
    
}

extension AppCoordinator: SettingsViewControllerDelegate {
    
    func settingsViewControllerClosed(_ controller: SettingsViewController) {
        rootViewController.dismiss(animated: true, completion: nil)
    }
    
}
