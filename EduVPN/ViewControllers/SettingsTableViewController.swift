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
    
    @IBAction func forceTcpChanged(_ sender: Any) {
        UserDefaults.standard.forceTcp = forceTcpSwitch.isOn
        delegate?.settingsTableViewControllerShouldReconnect(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        forceTcpSwitch.isOn = UserDefaults.standard.forceTcp
    }
}

extension SettingsTableViewController: Identifiable {}
