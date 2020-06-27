//
//  MainViewController.swift
//  EduVPN
//
//  Created by Johan Kool on 28/05/2020.
//  Copyright © 2020 SURFNet. All rights reserved.
//

import Foundation

class MainViewController: ViewController {

    var environment: Environment! {
        didSet {
            viewModel = MainViewModel(environment: environment)
            environment.navigationController?.delegate = self
            // We would load addedServers from disk in the future
            if addedServers.isEmpty {
                let searchVC = environment.instantiateSearchViewController()
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
        environment.navigationController?.pushViewController(searchVC, animated: true)
    }
}

extension MainViewController: SearchViewControllerDelegate {
    func searchViewControllerAddedServer(baseURL: URL, authState: AuthState) {
        let savedPath = "" // encryptAndSaveToDisk(baseURL, authState)
        addedServers[baseURL] = savedPath
    }
}
