//
//  ChooseProviderTableViewController.swift
//  EduVPN
//
//  Created by Jeroen Leenarts on 04-08-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

import UIKit

import AlamofireImage
import Moya

class ProviderTableViewCell: UITableViewCell {

    @IBOutlet weak var providerImageView: UIImageView!
    @IBOutlet weak var providerTitleLabel: UILabel!
}

protocol ChooseProviderTableViewControllerDelegate: class {
    func didSelect(instance: InstanceModel, chooseProviderTableViewController: ChooseProviderTableViewController)
}

class ChooseProviderTableViewController: UITableViewController {

    weak var delegate: ChooseProviderTableViewControllerDelegate?

    var providerType: ProviderType = .unknown

    var instances: InstancesModel? {
        didSet {
            self.tableView.reloadData()
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return (instances?.instances.count ?? 0)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ProviderCell", for: indexPath)

        if let providerCell = cell as? ProviderTableViewCell {
            let instance = instances!.instances[indexPath.row]
            if let logoUrl = instance.logoUrl {
                providerCell.providerImageView?.af_setImage(withURL: logoUrl)
            }
            providerCell.providerTitleLabel?.text = instance.displayName
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let instance = instances!.instances[indexPath.row]

        delegate?.didSelect(instance: instance, chooseProviderTableViewController: self)
    }
}

extension ChooseProviderTableViewController: Identifyable {}
