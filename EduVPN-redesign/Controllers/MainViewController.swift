//
//  MainViewController.swift
//  EduVPN
//
//  Created by Johan Kool on 28/05/2020.
//

import Foundation

protocol MainViewControllerDelegate: class {
    func mainViewControllerAddOtherServer(_ controller: MainViewController)
    func mainViewController(_ controller: MainViewController, connectToServer: AnyObject)
    func mainViewControllerChangeLocation(_ controller: MainViewController)
}

class MainViewController: ViewController {

    var environment: Environment! {
        didSet {
            viewModel = MainViewModel(environment: environment)
            environment.navigationController?.delegate = self
        }
    }

    var viewModel: MainViewModel!

    weak var delegate: MainViewControllerDelegate?

    private var addedServers: [URL: String] = [:]

    @IBOutlet private var addOtherServerButton: Button!

    @IBAction func addOtherServer(_ sender: Any) {
        delegate?.mainViewControllerAddOtherServer(self)
    }
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
