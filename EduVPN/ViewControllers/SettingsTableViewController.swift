//
//  SettingsTableViewController.swift
//  eduVPN
//
//  Created by Jeroen Leenarts on 14-08-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

import UIKit

protocol SettingsTableViewControllerDelegate: class {
    func readOnDemand() -> Bool
    func writeOnDemand(_ onDemand: Bool)
    func reconnect()
}

class SettingsTableViewController: UITableViewController {
    weak var delegate: SettingsTableViewControllerDelegate?

    @IBOutlet weak var onDemandSwitch: UISwitch!
    @IBOutlet weak var forceTcpSwitch: UISwitch!
    @IBOutlet weak var keysizeSegmentedControl: UISegmentedControl!

    @IBAction func onDemandChanged(_ sender: Any) {
        if let delegate = delegate {
            delegate.writeOnDemand(onDemandSwitch.isOn)
        } else {
            onDemandSwitch.isOn = false
        }

        delegate?.reconnect()
    }

    @IBAction func forceTcpChanged(_ sender: Any) {
        UserDefaults.standard.forceTcp = forceTcpSwitch.isOn
        delegate?.reconnect()
    }

    @IBAction func keySizeChanged(_ sender: Any) {
        switch keysizeSegmentedControl.selectedSegmentIndex {
        case 0:
            UserDefaults.standard.tlsSecurityLevel = TlsSecurityLevel.bits128
        case 1:
            UserDefaults.standard.tlsSecurityLevel = TlsSecurityLevel.bits192
        case 2:
            UserDefaults.standard.tlsSecurityLevel = TlsSecurityLevel.bits256
        default:
            fatalError("Unknown segment index.")
        }
        delegate?.reconnect()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        onDemandSwitch.isOn = delegate?.readOnDemand() ?? false
        forceTcpSwitch.isOn = UserDefaults.standard.forceTcp

        switch UserDefaults.standard.tlsSecurityLevel {
        case .bits128:
            keysizeSegmentedControl.selectedSegmentIndex = 0
        case .bits192:
            keysizeSegmentedControl.selectedSegmentIndex = 1
        case .bits256:
            keysizeSegmentedControl.selectedSegmentIndex = 2
        }
    }
}

extension SettingsTableViewController: Identifyable {}
