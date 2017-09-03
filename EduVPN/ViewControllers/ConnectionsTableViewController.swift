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

    var profilesModels = Set<ProfilesModel>() {
        didSet {
            instituteAccessModels.removeAll()
            internetAccessModels.removeAll()

            profilesModels.forEach { (profilesModel) in
                profilesModel.profiles.forEach({ (profileModel) in
                    if let providerType = profilesModel.instanceInfo?.instance?.providerType {
                        switch providerType {
                        case .instituteAccess:
                            instituteProfilesModel = profilesModel
                            instituteAccessModels.append(profileModel)
                        case .secureInternet:
                            internetProfilesModel = profilesModel
                            internetAccessModels.append(profileModel)
                        case .unknown:
                            return
                        }
                    }
                })
            }

            self.tableView.reloadData()
        }
    }

    private var internetProfilesModel: ProfilesModel?
    private var internetAccessModels = [ProfileModel]()
    private var instituteProfilesModel: ProfilesModel?
    private var instituteAccessModels = [ProfileModel]()

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

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return internetAccessModels.count
        default:
            return instituteAccessModels.count
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return NSLocalizedString("Internet access", comment: "")
        default:
            return NSLocalizedString("Institute access", comment: "")
        }
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch section {
        case 0:
            if internetAccessModels.isEmpty {
                return 0.0
            }
        default:
            if instituteAccessModels.isEmpty {
                return 0.0
            }
        }

        return tableView.sectionHeaderHeight
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let profileModel: ProfileModel
        let profilesModel: ProfilesModel?

        switch indexPath.section {
        case 0:
            profileModel = internetAccessModels[indexPath.row]
            profilesModel = internetProfilesModel
        default:
            profileModel = instituteAccessModels[indexPath.row]
            profilesModel = instituteProfilesModel
        }

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
