//
//  ConnectionsTableViewController.swift
//  EduVPN
//
//  Created by Jeroen Leenarts on 14-08-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

import UIKit

class ConnectTableViewCell: UITableViewCell {

    @IBOutlet weak var connectImageView: UIImageView!
    @IBOutlet weak var connectTitleLabel: UILabel!
    @IBOutlet weak var connectSubTitleLabel: UILabel!
}

extension ConnectTableViewCell: Identifyable {}

protocol ConnectionsTableViewControllerDelegate: class {
    func addProvider(connectionsTableViewController: ConnectionsTableViewController)
    func settings(connectionsTableViewController: ConnectionsTableViewController)

}

class ConnectionsTableViewController: UITableViewController {
    weak var delegate: ConnectionsTableViewControllerDelegate?

    var profiles = [ProfilesModel]() {
        didSet {
            profileToProfiles.removeAll()

            profileModels = profiles.reduce([], { (result, model) -> [ProfileModel] in
                model.profiles.forEach({ (profile) in
                    profileToProfiles[profile] = model
                })
                return result + model.profiles
            })
            self.tableView.reloadData()
        }
    }
    private var profileToProfiles = [ProfileModel: ProfilesModel]()
    private var profileModels = [ProfileModel]()

    var instanceInfoModels: [InstanceInfoModel]? {
        didSet {
            self.tableView.reloadData()
        }
    }

    @IBAction func addProvider(_ sender: Any) {
        delegate?.addProvider(connectionsTableViewController: self)
    }

    @IBAction func settings(_ sender: Any) {
        delegate?.settings(connectionsTableViewController: self)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return profileModels.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let profileModel = profileModels[indexPath.row]
        let profilesModel = profileToProfiles[profileModel]

        let cell = tableView.dequeueReusableCell(type: ConnectTableViewCell.self, for: indexPath)

        cell.connectTitleLabel?.text = profilesModel?.instanceInfo?.instance?.displayName
        cell.connectSubTitleLabel?.text = profileModel.displayName
        if let logoUri = profilesModel?.instanceInfo?.instance?.logoUrl {
            cell.connectImageView?.af_setImage(withURL: logoUri)
        } else {
            cell.connectImageView.af_cancelImageRequest()
            cell.connectImageView.image = nil
        }

        return cell
    }

}

extension ConnectionsTableViewController: Identifyable {}
