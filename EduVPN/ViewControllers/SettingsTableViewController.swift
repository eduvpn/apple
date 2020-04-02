//
//  SettingsTableViewController.swift
//  eduVPN
//

import UIKit

protocol SettingsTableViewControllerDelegate: class {
    func settingsTableViewControllerShouldReconnect(_ controller: SettingsTableViewController)
}

class SettingsTableViewController: UITableViewController {
    weak var delegate: SettingsTableViewControllerDelegate?
    
    @IBOutlet weak var forceTcpSwitch: UISwitch!
    @IBOutlet weak var useNewDiscoveryMethodSwitch: UISwitch!

    @IBAction func forceTcpChanged(_ sender: Any) {
        UserDefaults.standard.forceTcp = forceTcpSwitch.isOn
        delegate?.settingsTableViewControllerShouldReconnect(self)
    }

    @IBAction func useNewDiscoveryMethodChanged(_ sender: Any) {
        UserDefaults.standard.useNewDiscoveryMethod = useNewDiscoveryMethodSwitch.isOn
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        forceTcpSwitch.isOn = UserDefaults.standard.forceTcp
        useNewDiscoveryMethodSwitch.isOn = UserDefaults.standard.useNewDiscoveryMethod
    }
}

extension SettingsTableViewController: Identifiable {}
