//
//  SettingsViewController.swift
//  EduVPN
//

import UIKit
import SafariServices

enum SettingsViewControllerError: Error {
    case noLogAvailable
    case cannotShowLog
}

extension SettingsViewControllerError: AppError {
    var summary: String {
        switch self {
        case .noLogAvailable: return NSLocalizedString("No log available", comment: "")
        case .cannotShowLog: return NSLocalizedString("Unable to show log", comment: "")
        }
    }
}

class SettingsViewController: UITableViewController, ParametrizedViewController {

    struct Parameters {
        let environment: Environment
    }

    private var parameters: Parameters!

    @IBOutlet weak var useTCPOnlySwitch: UISwitch!
    @IBOutlet weak var appNameLabel: UILabel!
    @IBOutlet weak var appVersionLabel: UILabel!

    func initializeParameters(_ parameters: Parameters) {
        guard self.parameters == nil else {
            fatalError("Can't initialize parameters twice")
        }
        self.parameters = parameters
    }

    override func viewDidLoad() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done, target: self, action: #selector(doneTapped(_:)))

        let userDefaults = UserDefaults.standard
        let isForceTCPEnabled = userDefaults.forceTCP

        useTCPOnlySwitch.isOn = isForceTCPEnabled

        appNameLabel.text = Config.shared.appName
        appVersionLabel.text = appVersionString()
    }

    @IBAction func useTCPOnlySwitchToggled(_ sender: Any) {
        UserDefaults.standard.forceTCP = useTCPOnlySwitch.isOn
    }

    @IBAction func importOpenVPNConfigTapped(_ sender: Any) {
        print("Import clicked")
    }

    @objc func doneTapped(_ sender: Any) {
        presentingViewController?.dismiss(animated: true, completion: nil)
    }

    private func appVersionString() -> String {
        let shortVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? ""
        let bundleVersion = (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? ""
        return "\(shortVersion) (\(bundleVersion))"
    }
}

extension SettingsViewController {
    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        if indexPath.section == 1 && indexPath.row == 0 {
            // This is a 'Connection Log' row
            return indexPath
        }
        if indexPath.section == 2 && indexPath.row == 1 {
            // This is a 'Source code' row
            return indexPath
        }
        return nil
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 1 && indexPath.row == 0 {
            // This is a 'Connection Log' row
            let logVC = parameters.environment.instantiateLogViewController()
            navigationController?.pushViewController(logVC, animated: true)
        }
        if indexPath.section == 2 && indexPath.row == 1 {
            // This is a 'Source code' row
            if let sourceCodeURL = URL(string: "https://github.com/eduvpn/apple") {
                let safariVC = SFSafariViewController(url: sourceCodeURL)
                present(safariVC, animated: true, completion: nil)
            }
        }
    }
}
