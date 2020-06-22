//
//  Environment.swift
//  eduVPN 2
//
//  Created by Johan Kool on 28/05/2020.
//  Copyright © 2020 SURFNet. All rights reserved.
//

import Foundation

protocol ParametrizedViewController: ViewController {
    associatedtype Parameters
    var parameters: Parameters! { get set }
    init?(coder: NSCoder, parameters: Parameters)
}

class Environment {
    private lazy var config = Config.shared
    private lazy var storyboard = Storyboard(name: "Main", bundle: nil)
    weak var navigationController: NavigationController?
    // Services to be added

    static let isInstantiatingUsingCreatorBlocks = true

    init(navigationController: NavigationController) {
        self.navigationController = navigationController
    }

    func instantiateSearchViewController() -> SearchViewController {
        let parameters = SearchViewController.Parameters(environment: self)
        return instantiate(SearchViewController.self, identifier: "Search", parameters: parameters)
    }

    func instantiate<VC: ParametrizedViewController>(_ type: VC.Type, identifier: String,
                                                     parameters: VC.Parameters) -> VC {
        // In macOS 10.15 / iOS 13 and later, we can pass our own parameters to
        // view controllers when instantiating them.
        // For earlier OS versions, we have to inject them ourselves by setting
        // the 'parameters' property of the view controller.
        // If 'isInstantiatingUsingCreatorBlocks' is false, we use the injecting
        // code even in the new OS, to facilitate testing of the injecting
        // mechanism in the new OS.

        if #available(macOS 10.15, iOS 13, *), Environment.isInstantiatingUsingCreatorBlocks {
            return storyboard.instantiateViewController(identifier: identifier) { coder -> VC? in
                return VC(coder: coder, parameters: parameters)
            }
        } else {
            guard let viewController = storyboard.instantiateViewController(withIdentifier: identifier) as? VC else {
                fatalError("Can't instantiate view controller with identifier: \(identifier)")
            }
            viewController.parameters = parameters
            return viewController
        }
    }
}
