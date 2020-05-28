//
//  SearchCoordinator.swift
//  EduVPN
//
//  Created by Johan Kool on 28/05/2020.
//  Copyright © 2020 SURFNet. All rights reserved.
//

import Foundation

protocol SearchCoordinatorDelegate: class {
    func searchCoordinatorDidFinish(_ coordinator: SearchCoordinator)
}

class SearchCoordinator: Coordinator {
    
    var presentingViewController: ViewController
    weak var delegate: SearchCoordinatorDelegate?
    var childCoordinators: [Coordinator] = []
    let environment: Environment
    
    init(presentingViewController: ViewController, delegate: SearchCoordinatorDelegate, environment: Environment) {
        self.presentingViewController = presentingViewController
        self.delegate = delegate
        self.environment = environment
    }
    
    func start() {
        let searchViewController = SearchViewController(viewModel: SearchViewModel(environment: environment), delegate: self)
        // presentingViewController.present(searchViewController) // TODO: Generic way to present
    }
    
    private func addOtherServer() {
        let addOtherViewController = AddOtherViewController(viewModel: AddOtherViewModel(environment: environment), delegate: self)
        // presentingViewController.present(addOtherViewController) // TODO: Generic way to present
    }
    
}

extension SearchCoordinator: SearchViewControllerDelegate {
    
    func searchViewControllerAddOtherServer(_ controller: SearchViewController) {
        // TODO
    }
    
    func searchViewController(_ controller: SearchViewController, selectedInstitute: AnyObject) {
        // TODO
    }
    
    func searchViewControllerCancelled(_ controller: SearchViewController) {
        presentingViewController.dismiss(controller)
        delegate?.searchCoordinatorDidFinish(self)
    }
    
}


extension SearchCoordinator: AddOtherViewControllerDelegate {
    
    func addOtherViewController(_ controller: AddOtherViewController, addedServer: AnyObject) {
        presentingViewController.dismiss(controller)
        delegate?.searchCoordinatorDidFinish(self)
    }
    
    func addOtherViewControllerCancelled(_ controller: AddOtherViewController) {
        presentingViewController.dismiss(controller)
    }
    
}
