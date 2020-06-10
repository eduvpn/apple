//
//  MainCoordinator.swift
//  EduVPN
//
//  Created by Johan Kool on 28/05/2020.
//  Copyright © 2020 SURFNet. All rights reserved.
//

import Foundation

class MainCoordinator: Coordinator {
  
    let rootViewController: NavigationController
    var childCoordinators: [Coordinator] = []
    let environment: Environment
    
    init(rootViewController: NavigationController, environment: Environment) {
        self.rootViewController = rootViewController
        self.environment = environment
    }
    
    func start() {
        let mainViewController = environment.storyboard.instantiateViewController(withIdentifier: "Main") as! MainViewController
        mainViewController.delegate = self
        mainViewController.viewModel = MainViewModel(environment: environment)
//        let mainViewController = MainViewController(viewModel: MainViewModel(environment: environment), delegate: self)
//        rootViewController.present(mainViewController, animated: false, completion: nil)
        rootViewController.viewControllers = [mainViewController]
    }
    
    private func addOtherServer() {
        let searchCoordinator = SearchCoordinator(presentingViewController: rootViewController, delegate: self, environment: environment)
        addChildCoordinator(searchCoordinator)
        searchCoordinator.start()
    }
    
    private func connectToServer(server: AnyObject) {
        let connectionCoordinator = ConnectionCoordinator(presentingViewController: rootViewController, delegate: self, environment: environment)
        addChildCoordinator(connectionCoordinator)
        connectionCoordinator.start()
    }
    
}

extension MainCoordinator: MainViewControllerDelegate {
    
    func mainViewControllerAddOtherServer(_ controller: MainViewController) {
        addOtherServer()
    }
    
    func mainViewController(_ controller: MainViewController, connectToServer server: AnyObject) {
        connectToServer(server: server)
    }
    
    func mainViewControllerChangeLocation(_ controller: MainViewController) {
        // TODO: Present view/popup to change location
    }
    
}

extension MainCoordinator: SearchCoordinatorDelegate {
    
    func searchCoordinatorDidFinish(_ coordinator: SearchCoordinator) {
        removeChildCoordinator(coordinator)
    }
    
}

extension MainCoordinator: ConnectionCoordinatorDelegate {
    
    func connectionCoordinatorDidFinish(_ coordinator: ConnectionCoordinator) {
        removeChildCoordinator(coordinator)
    }
    
}
