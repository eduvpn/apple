//
//  ConnectionsViewController.swift
//  EduVPN
//
//  Created by Jeroen Leenarts on 14-08-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

import UIKit

protocol ConnectionsViewControllerDelegate: class {
    func addProvider(connectionsViewController: ConnectionsViewController)
}

class ConnectionsViewController: UIViewController {
    weak var delegate: ConnectionsViewControllerDelegate?

    @IBAction func addProvider(_ sender: Any) {
        delegate?.addProvider(connectionsViewController: self)
    }
}

extension ConnectionsViewController: Identifyable {}
