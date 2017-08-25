//
//  ConnectionsTableViewController.swift
//  EduVPN
//
//  Created by Jeroen Leenarts on 14-08-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

import UIKit

protocol ConnectionsTableViewControllerDelegate: class {
    func addProvider(connectionsTableViewController: ConnectionsTableViewController)
    func settings(connectionsTableViewController: ConnectionsTableViewController)

}

class ConnectionsTableViewController: UITableViewController {
    weak var delegate: ConnectionsTableViewControllerDelegate?

    @IBAction func addProvider(_ sender: Any) {
        delegate?.addProvider(connectionsTableViewController: self)
    }

    @IBAction func settings(_ sender: Any) {
        delegate?.settings(connectionsTableViewController: self)
    }

//    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
//        let instance = instances!.instances[indexPath.row]
//
//        let cell = tableView.dequeueReusableCell(withIdentifier: "ProviderCell", for: indexPath)
//
//        if let providerCell = cell as? ProviderTableViewCell {
//            providerCell.providerImageView?.af_setImage(withURL: instance.logoUri)
//            providerCell.providerTitleLabel?.text = instance.displayName
//        }
//        return cell
//    }

}

extension ConnectionsTableViewController: Identifyable {}
