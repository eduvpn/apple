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
    func delete(profile: ProfileModel, for instanceInfo: InstanceInfoModel)

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

    var otherInstancesModel: InstancesModel? {
        didSet {
            dataUpdated()
        }
    }

    var instanceInfoProfilesMapping: [InstanceInfoModel: ProfilesModel] = [InstanceInfoModel: ProfilesModel]() {
        didSet {
            dataUpdated()
        }
    }

    private func dataUpdated() {
        internetAccessModels.removeAll()
        instituteAccessModels.removeAll()
        otherAccessModels.removeAll()
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

        otherInstancesModel?.instances.forEach({ (instance) in
            if let instanceInfo = instance.instanceInfo {
                instanceInfoProfilesMapping[instanceInfo]?.profiles.forEach({ (profile) in
                    otherAccessModels.append(profile)
                    profileInstanceMapping[profile] = instance
                })
            }
        })
        self.tableView.reloadData()
    }

    private var internetAccessModels = [ProfileModel]()
    private var instituteAccessModels = [ProfileModel]()
    private var otherAccessModels = [ProfileModel]()
    private var profileInstanceMapping = [ProfileModel: InstanceModel]()

    @IBAction func addProvider(_ sender: Any) {
        delegate?.addProvider(connectionsTableViewController: self)
    }

    @IBAction func settings(_ sender: Any) {
        delegate?.settings(connectionsTableViewController: self)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return internetAccessModels.count
        case 1:
            return instituteAccessModels.count
        default:
            return otherAccessModels.count
        }
    }

    var empty: Bool {
        return internetAccessModels.count + instituteAccessModels.count + otherAccessModels.count == 0
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return NSLocalizedString("Secure Internet", comment: "")
        case 1:
            return NSLocalizedString("Institute access", comment: "")
        default:
            return NSLocalizedString("Other", comment: "")
        }
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch section {
        case 0:
            if internetAccessModels.isEmpty {
                return 0.0
            }
        case 1:
            if instituteAccessModels.isEmpty {
                return 0.0
            }
        default:
            if otherAccessModels.isEmpty {
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
        case 1:
            profileModel = instituteAccessModels[indexPath.row]
        default:
            profileModel = otherAccessModels[indexPath.row]
        }

        let instanceModel = profileInstanceMapping[profileModel]

        let cell = tableView.dequeueReusableCell(type: ConnectTableViewCell.self, for: indexPath)

        cell.connectTitleLabel?.text = profileModel.displayName
        cell.connectSubTitleLabel?.text = instanceModel?.displayName ?? profileModel.displayName
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
        case 1:
            profileModel = instituteAccessModels[indexPath.row]
        default:
            profileModel = otherAccessModels[indexPath.row]
        }

        if let instance = profileInstanceMapping[profileModel] {
            delegate?.connect(profile: profileModel, on: instance)
        }

        tableView.deselectRow(at: indexPath, animated: true)
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {

            let profileModel: ProfileModel

            switch indexPath.section {
            case 0:
                profileModel = internetAccessModels[indexPath.row]
            case 1:
                profileModel = instituteAccessModels[indexPath.row]
            default:
                profileModel = otherAccessModels[indexPath.row]
            }

            if let instanceInfoModel = profileInstanceMapping[profileModel]?.instanceInfo {
                delegate?.delete(profile: profileModel, for: instanceInfoModel)
            }
        }
    }
}

extension ConnectionsTableViewController: Identifyable {}
