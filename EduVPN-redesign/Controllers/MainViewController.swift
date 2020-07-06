//
//  MainViewController.swift
//  EduVPN
//
//  Created by Johan Kool on 28/05/2020.
//

import Foundation

class MainViewController: ViewController {

    var environment: Environment! {
        didSet {
            viewModel = MainViewModel(
                persistenceService: environment.persistenceService,
                serverDiscoveryService: environment.serverDiscoveryService)
            environment.navigationController?.delegate = self
            // We would load addedServers from disk in the future
            if addedServers.isEmpty {
                let searchVC = environment.instantiateSearchViewController()
                searchVC.delegate = self
                environment.navigationController?.pushViewController(searchVC, animated: false)
                environment.navigationController?.isUserAllowedToGoBack = false
            }
        }
    }

    var viewModel: MainViewModel!

    private var addedServers: [URL: String] = [:]
}

extension MainViewController: NavigationControllerDelegate {
    func addServerButtonClicked() {
        let searchVC = environment.instantiateSearchViewController()
        searchVC.delegate = self
        environment.navigationController?.pushViewController(searchVC, animated: true)
    }
}

extension MainViewController: SearchViewControllerDelegate {
    func searchViewControllerAddedSimpleServer(baseURL: URL, authState: AuthState) {
        let storagePath = UUID().uuidString
        let dataStore = PersistenceService.ServerDataStore(path: storagePath)
        dataStore.authState = authState
        let server = SimpleServerInstance(baseURL: baseURL, localStoragePath: storagePath)
        environment.persistenceService.addSimpleServer(server)
        environment.navigationController?.popViewController(animated: true)
    }

    func searchViewControllerAddedSecureInternetServer(baseURL: URL, orgId: String, authState: AuthState) {
        let storagePath = UUID().uuidString
        let dataStore = PersistenceService.ServerDataStore(path: storagePath)
        dataStore.authState = authState
        let server = SecureInternetServerInstance(
            apiBaseURL: baseURL, authBaseURL: baseURL,
            orgId: orgId, localStoragePath: storagePath)
        environment.persistenceService.setSecureInternetServer(server)
        environment.navigationController?.popViewController(animated: true)
    }
}
