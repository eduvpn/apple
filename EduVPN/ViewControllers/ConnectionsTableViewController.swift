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
    func connect(profile: ProfileModel, on instance: InstanceModel)
}

class ConnectionsTableViewController: UITableViewController {
    weak var delegate: ConnectionsTableViewControllerDelegate?

    var internetInstancesModel: InstancesModel? {
        didSet {
            dataUpdated()
        }
    }
    var instituteInstancesModel: InstancesModel? {
    didSet {
        dataUpdated()
        }
    }

    var instanceInfoProfilesMapping: [InstanceInfoModel:ProfilesModel] = [InstanceInfoModel: ProfilesModel]() {
        didSet {
            dataUpdated()
        }
    }

    private func dataUpdated() {
        internetAccessModels.removeAll()
        instituteAccessModels.removeAll()
        profileInstanceMapping.removeAll()

        internetInstancesModel?.instances.forEach({ (instance) in
            if let instanceInfo = instance.instanceInfo {
                instanceInfoProfilesMapping[instanceInfo]?.profiles.forEach({ (profile) in
                    internetAccessModels.append(profile)
                    profileInstanceMapping[profile] = instance
                })
            }
        })

        instituteInstancesModel?.instances.forEach({ (instance) in
            if let instanceInfo = instance.instanceInfo {
                instanceInfoProfilesMapping[instanceInfo]?.profiles.forEach({ (profile) in
                    instituteAccessModels.append(profile)
                    profileInstanceMapping[profile] = instance
                })
            }
        })
        self.tableView.reloadData()
    }

    private var internetAccessModels = [ProfileModel]()
    private var instituteAccessModels = [ProfileModel]()
    private var profileInstanceMapping = [ProfileModel: InstanceModel]()

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

        switch indexPath.section {
        case 0:
            profileModel = internetAccessModels[indexPath.row]
        default:
            profileModel = instituteAccessModels[indexPath.row]
        }

        let cell = tableView.dequeueReusableCell(type: ConnectTableViewCell.self, for: indexPath)

        cell.connectTitleLabel?.text = profileModel.displayName
        cell.connectSubTitleLabel?.text = profileModel.displayName
        if let logoUri = profileInstanceMapping[profileModel]?.logoUrl {
            cell.connectImageView?.af_setImage(withURL: logoUri)
        } else {
            cell.connectImageView.af_cancelImageRequest()
            cell.connectImageView.image = nil
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let profileModel: ProfileModel

        switch indexPath.section {
        case 0:
            profileModel = internetAccessModels[indexPath.row]
        default:
            profileModel = instituteAccessModels[indexPath.row]
        }

        if let instance = profileInstanceMapping[profileModel] {
            delegate?.connect(profile:profileModel, on: instance)
        }

        tableView.deselectRow(at: indexPath, animated: true)
    }
}

extension ConnectionsTableViewController: Identifyable {}
