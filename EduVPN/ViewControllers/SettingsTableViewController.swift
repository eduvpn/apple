//
//  SettingsTableViewController.swift
//  EduVPN
//
//  Created by Jeroen Leenarts on 14-08-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

import UIKit

protocol SettingsTableViewControllerDelegate: class {
    func readOnDemand() -> Bool
    func writeOnDemand(_ onDemand: Bool)
}

class SettingsTableViewController: UITableViewController {
    weak var delegate: SettingsTableViewControllerDelegate?

    @IBOutlet weak var onDemandSwitch: UISwitch!
    @IBOutlet weak var forceTcpSwitch: UISwitch!
    
    @IBAction func onDemandChanged(_ sender: Any) {
        if let delegate = delegate {
            delegate.writeOnDemand(onDemandSwitch.isOn)
        } else {
            onDemandSwitch.isOn = false
        }
    }

    @IBAction func forceTcpChanged(_ sender: Any) {
        UserDefaults.standard.forceTcp = forceTcpSwitch.isOn
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        onDemandSwitch.isOn = delegate?.readOnDemand() ?? false
//        forceTcpSwitch.isOn = UserDefaults.standard.forceTcp
    }
}

extension SettingsTableViewController: Identifyable {}
