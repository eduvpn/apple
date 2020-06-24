//
//  SearchViewController.swift
//  EduVPN
//
//  Created by Johan Kool on 28/05/2020.
//  Copyright © 2020 SURFNet. All rights reserved.
//

import Foundation

protocol SearchViewControllerDelegate: class {
    func searchViewControllerAddOtherServer(_ controller: SearchViewController)
    func searchViewController(_ controller: SearchViewController, selectedInstitute: AnyObject)
    func searchViewControllerCancelled(_ controller: SearchViewController)
}

final class SearchViewController: ViewController, ParametrizedViewController {
    struct Parameters {
        let environment: Environment
    }

    weak var delegate: SearchViewControllerDelegate?

    private var parameters: Parameters!
    private var viewModel: SearchViewModel!

    @IBOutlet private var cancelButton: Button!

    func initializeParameters(_ parameters: Parameters) {
        guard self.parameters == nil else {
            fatalError("Can't initialize parameters twice")
        }
        self.parameters = parameters
        self.viewModel = SearchViewModel(
            serverDiscoveryService: parameters.environment.serverDiscoveryService)
    }

    @IBAction func cancel(_ sender: Any) {
        delegate?.searchViewControllerCancelled(self)
    }
}
