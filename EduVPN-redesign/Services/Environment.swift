//
//  Environment.swift
//  eduVPN 2
//
//  Created by Johan Kool on 28/05/2020.
//  Copyright © 2020 SURFNet. All rights reserved.
//

import Foundation

class Environment {
    private lazy var config = Config.shared
    private lazy var storyboard = Storyboard(name: "Main", bundle: nil)
    weak var navigationController: NavigationController?
    // Services to be added

    init(navigationController: NavigationController) {
        self.navigationController = navigationController
    }

    func instantiateSearchViewController() -> SearchViewController {
        let viewController = instantiate(SearchViewController.self, identifier: "Search")
        viewController.environment = self
        return viewController
    }

    private func instantiate<VC: ViewController>(_ type: VC.Type, identifier: String) -> VC {
        return storyboard.instantiateViewController(withIdentifier: identifier)
            as! VC // swiftlint:disable:this force_cast
    }
}
