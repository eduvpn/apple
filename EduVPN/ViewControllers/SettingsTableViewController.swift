//
//  SettingsTableViewController.swift
//  EduVPN
//
//  Created by Jeroen Leenarts on 14-08-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

import UIKit

protocol SettingsTableViewControllerDelegate: class {

}

class SettingsTableViewController: UITableViewController {
    weak var delegate: SettingsTableViewControllerDelegate?

    @IBOutlet weak var forceTcpSwitch: UISwitch!

    @IBAction func forceTcpChanged(_ sender: Any) {
        UserDefaults.standard.forceTcp = forceTcpSwitch.isOn
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        forceTcpSwitch.isOn = UserDefaults.standard.forceTcp
    }
}

extension SettingsTableViewController: Identifyable {}
