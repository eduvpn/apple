//
//  SettingsViewController.swift
//  EduVPN
//

import UIKit
import SafariServices
import PromiseKit

enum SettingsViewControllerError: Error {
    case noLogAvailable
    case cannotShowLog
}

extension SettingsViewControllerError: AppError {
    var summary: String {
        switch self {
        case .noLogAvailable: return NSLocalizedString("No log available", comment: "Error message")
        case .cannotShowLog: return NSLocalizedString("Unable to show log", comment: "Error message")
        }
    }
}

class SettingsViewController: UITableViewController, ParametrizedViewController {

    struct Parameters {
        let environment: Environment
        let mainVC: MainViewController
    }

    private var parameters: Parameters!

    @IBOutlet weak var useTCPOnlySwitch: UISwitch!
    @IBOutlet weak var sessionExpiryNotificationSwitch: UISwitch!
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
        let shouldNotifyBeforeSessionExpiry = userDefaults.shouldNotifyBeforeSessionExpiry

        useTCPOnlySwitch.isOn = isForceTCPEnabled
        sessionExpiryNotificationSwitch.isOn = shouldNotifyBeforeSessionExpiry

        appNameLabel.text = Config.shared.appName
        appVersionLabel.text = appVersionString()
    }

    @IBAction func useTCPOnlySwitchToggled(_ sender: Any) {
        UserDefaults.standard.forceTCP = useTCPOnlySwitch.isOn
    }

    @IBAction func sessionExpiryNotificationSwitchToggled(_ sender: Any) {
        let isSessionExpiryNotificationChecked = sessionExpiryNotificationSwitch.isOn
        let notificationService = parameters.environment.notificationService
        let mainVC = parameters.mainVC
        if isSessionExpiryNotificationChecked {
            firstly {
                notificationService.enableSessionExpiryNotifications(from: self)
            }.done { isEnabled in
                if isEnabled {
                    mainVC.scheduleSessionExpiryNotificationOnActiveVPN()
                        .done { _ in }
                } else {
                    self.sessionExpiryNotificationSwitch.isOn = false
                }
            }
        } else {
            notificationService.disableSessionExpiryNotifications()
            notificationService.descheduleSessionExpiryNotifications()
        }
    }

    @IBAction func importOpenVPNConfigTapped(_ sender: Any) {
        let types = ["net.openvpn.formats.ovpn"]
        let pickerVC = UIDocumentPickerViewController(documentTypes: types, in: .import)
        pickerVC.allowsMultipleSelection = false
        pickerVC.delegate = self
        present(pickerVC, animated: true, completion: nil)
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
        if indexPath.section == 2 && indexPath.row == 0 {
            // This is a 'Connection Log' row
            return indexPath
        }
        if indexPath.section == 4 && indexPath.row == 1 {
            // This is a 'Source code' row
            return indexPath
        }
        return nil
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 2 && indexPath.row == 0 {
            // This is a 'Connection Log' row
            let logVC = parameters.environment.instantiateLogViewController()
            navigationController?.pushViewController(logVC, animated: true)
        }
        if indexPath.section == 4 && indexPath.row == 1 {
            // This is a 'Source code' row
            if let sourceCodeURL = URL(string: "https://github.com/eduvpn/apple") {
                let safariVC = SFSafariViewController(url: sourceCodeURL)
                present(safariVC, animated: true, completion: nil)
            }
        }
    }
}

extension SettingsViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        let ovpnURLs = urls.filter { $0.pathExtension.lowercased() == "ovpn" }
        guard let url = ovpnURLs.first else { return }

        let persistenceService = parameters.environment.persistenceService
        let mainVC = parameters.mainVC

        var importError: Error?
        do {
            let result = try OpenVPNConfigImportHelper.copyConfig(from: url)
            if result.hasAuthUserPass {
                let credentialsVC = parameters.environment.instantiateCredentialsViewController(
                    initialCredentials: OpenVPNConfigCredentials.emptyCredentials)
                credentialsVC.onCredentialsSaved = { credentials in
                    let dataStore = PersistenceService.DataStore(
                        path: result.configInstance.localStoragePath)
                    dataStore.openVPNConfigCredentials = credentials
                    persistenceService.addOpenVPNConfiguration(result.configInstance)
                    mainVC.refresh()
                }
                let navigationVC = UINavigationController(rootViewController: credentialsVC)
                navigationVC.modalPresentationStyle = .pageSheet
                present(navigationVC, animated: true, completion: nil)
            } else {
                persistenceService.addOpenVPNConfiguration(result.configInstance)
            }
        } catch {
            importError = error
        }

        parameters.mainVC.refresh()

        if let importError = importError {
            if let navigationController = parameters.environment.navigationController {
                navigationController.showAlert(for: importError)
            }
        }
    }
}
