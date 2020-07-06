//
//  SearchCoordinator.swift
//  EduVPN
//
//  Created by Johan Kool on 28/05/2020.
//

import Foundation

protocol SearchCoordinatorDelegate: class {
    func searchCoordinatorDidFinish(_ coordinator: SearchCoordinator)
}

class SearchCoordinator: Coordinator {
    
    var presentingViewController: PresentingController
    weak var delegate: SearchCoordinatorDelegate?
    var childCoordinators: [Coordinator] = []
    let environment: Environment
    
    init(presentingViewController: PresentingController, delegate: SearchCoordinatorDelegate, environment: Environment) {
        self.presentingViewController = presentingViewController
        self.delegate = delegate
        self.environment = environment
    }
    
    func start() {
        guard let searchViewController = environment.storyboard.instantiateViewController(withIdentifier: "Search") as? SearchViewController else {
            return
        }
        searchViewController.viewModel = SearchViewModel(environment: environment)
        searchViewController.delegate = self
        presentingViewController.present(searchViewController, animated: true, completion: nil)
    }
    
    private func addOtherServer() {
        let addOtherViewController = AddOtherViewController(viewModel: AddOtherViewModel(environment: environment), delegate: self)
        presentingViewController.present(addOtherViewController, animated: true, completion: nil)
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
        presentingViewController.dismiss(animated: true, completion: nil)
        delegate?.searchCoordinatorDidFinish(self)
    }
    
}


extension SearchCoordinator: AddOtherViewControllerDelegate {
    
    func addOtherViewController(_ controller: AddOtherViewController, addedServer: AnyObject) {
        presentingViewController.dismiss(animated: true, completion: nil)
        delegate?.searchCoordinatorDidFinish(self)
    }
    
    func addOtherViewControllerCancelled(_ controller: AddOtherViewController) {
        presentingViewController.dismiss(animated: true, completion: nil)
    }
    
}
