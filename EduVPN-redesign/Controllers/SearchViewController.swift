//
//  SearchViewController.swift
//  EduVPN
//
//  Created by Johan Kool on 28/05/2020.
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

    var parameters: Parameters! {
        didSet {
            viewModel = SearchViewModel(serverDiscoveryService: parameters.environment.serverDiscoveryService)
        }
    }

    var viewModel: SearchViewModel!

    weak var delegate: SearchViewControllerDelegate?

    @IBOutlet private var cancelButton: Button!

    init?(coder: NSCoder, parameters: Parameters) {
        self.parameters = parameters
        super.init(coder: coder)
    }

    required init?(coder: NSCoder) {
        if #available(macOS 10.15, iOS 13, *), Environment.isInstantiatingUsingCreatorBlocks {
            fatalError("init(coder:) should not be called")
        } else {
            super.init(coder: coder)
        }
    }

    @IBAction func cancel(_ sender: Any) {
        delegate?.searchViewControllerCancelled(self)
    }
}
