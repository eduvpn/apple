//
//  ConnectionTypeViewController.swift
//  EduVPN
//
//  Created by Jeroen Leenarts on 08-08-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

import UIKit

protocol ConnectionTypeViewControllerDelegate: class {
    func connectionTypeViewControllerDidSelectProviderType(connectionTypeViewController: ConnectionTypeViewController, providerType: ProviderType)
}

class ConnectionTypeViewController: UIViewController {

    weak var delegate: ConnectionTypeViewControllerDelegate?

    @IBAction func didTapSecureAccess(_ sender: Any) {
        self.delegate?.connectionTypeViewControllerDidSelectProviderType(connectionTypeViewController: self, providerType: .secureInternet)
    }

    @IBAction func didTapInstituteAccess(_ sender: Any) {
        self.delegate?.connectionTypeViewControllerDidSelectProviderType(connectionTypeViewController: self, providerType: .instituteAccess)
    }
}
