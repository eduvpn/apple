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
    func chooseProviderTableViewControllerDidSelectProviderType(chooseProviderTableViewController: ChooseProviderTableViewController)
}

class ChooseProviderTableViewController: UITableViewController {

    weak var delegate: ChooseProviderTableViewControllerDelegate?

    let instancesFileManager = ApplicationSupportFileManager(filename: "instances.dat")
    var instances: Instances? {
        didSet {
            self.tableView.reloadData()
        }
    }

    override func viewWillAppear(_ animated: Bool) {

        if let instancesData: [String: Any] = instancesFileManager.loadFromDisk() {
            instances = Instances(json: instancesData)
        }

        print("local instances \(String(describing: instances))")

        let provider = MoyaProvider<StaticService>()
        _ = provider.request(target: .instances).then { response -> Void in

            self.instances = try response.mapResponseToInstances()

            if self.instances != nil {
                //Store response to disk
                self.instancesFileManager.persistToDisk(data: self.instances?.jsonDictionary)
            }

            print("loaded from network: \(String(describing: self.instances))")
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return instances?.instances.count ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let instance = instances!.instances[indexPath.row]

        let cell = tableView.dequeueReusableCell(withIdentifier: "ProviderCell", for: indexPath)

        if let providerCell = cell as? ProviderTableViewCell {
            providerCell.providerImageView?.af_setImage(withURL: instance.logoUri)
            providerCell.providerTitleLabel?.text = instance.displayName
        }
        return cell
    }
}
