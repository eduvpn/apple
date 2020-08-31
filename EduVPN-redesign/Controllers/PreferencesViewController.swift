//
//  PreferencesViewController.swift
//  EduVPN
//

import Foundation

class PreferencesViewController: ViewController {

    @IBOutlet weak var useTCPOnlyCheckbox: NSButton!

    override func viewDidLoad() {
        let isForceTCPEnabled = UserDefaults.standard.forceTCP
        useTCPOnlyCheckbox.state = isForceTCPEnabled ? .on : .off
    }

    @IBAction func useTCPOnlyCheckboxClicked(_ sender: Any) {
        let isUseTCPOnlyChecked = (useTCPOnlyCheckbox.state == .on)
        UserDefaults.standard.forceTCP = isUseTCPOnlyChecked
    }

    @IBAction func viewLogClicked(_ sender: Any) {
    }

    @IBAction func doneClicked(_ sender: Any) {
        self.presentingViewController?.dismiss(self)
    }
}
