//
//  PreferencesViewController.swift
//  EduVPN
//

import Foundation
import PromiseKit

enum PreferencesViewControllerError: Error {
    case noLogAvailable
    case cannotShowLog
}

extension PreferencesViewControllerError: AppError {
    var summary: String {
        switch self {
        case .noLogAvailable: return NSLocalizedString("No log available", comment: "")
        case .cannotShowLog: return NSLocalizedString("Unable to show log", comment: "")
        }
    }
}

class PreferencesViewController: ViewController, ParametrizedViewController {

    struct Parameters {
        let environment: Environment
    }

    private var parameters: Parameters!

    @IBOutlet weak var useTCPOnlyCheckbox: NSButton!
    @IBOutlet weak var showInStatusBarCheckbox: NSButton!
    @IBOutlet weak var showInDockCheckbox: NSButton!
    @IBOutlet weak var launchAtLoginCheckbox: NSButton!
    @IBOutlet weak var assistPathUpgradingCheckbox: NSButton!

    func initializeParameters(_ parameters: Parameters) {
        guard self.parameters == nil else {
            fatalError("Can't initialize parameters twice")
        }
        self.parameters = parameters
    }

    override func viewDidLoad() {
        let userDefaults = UserDefaults.standard
        let isForceTCPEnabled = userDefaults.forceTCP
        let isShowInStatusBarEnabled = userDefaults.showInStatusBar
        let isShowInDockEnabled = userDefaults.showInDock
        let isLaunchAtLoginEnabled = userDefaults.launchAtLogin
        let isAssistPathUpgradingEnabled = userDefaults.assistPathUpgradingWithPathMonitor

        useTCPOnlyCheckbox.state = isForceTCPEnabled ? .on : .off
        showInStatusBarCheckbox.state = isShowInStatusBarEnabled ? .on : .off
        showInDockCheckbox.state = isShowInDockEnabled ? .on : .off
        launchAtLoginCheckbox.state = isLaunchAtLoginEnabled ? .on : .off
        assistPathUpgradingCheckbox.state = isAssistPathUpgradingEnabled ? .on : .off

        // If one of "Show in status bar" or "Show in Dock" is off,
        // disable editing the other
        if !isShowInStatusBarEnabled {
            showInDockCheckbox.isEnabled = false
        }
        if !isShowInDockEnabled {
            showInStatusBarCheckbox.isEnabled = false
        }
    }

    @IBAction func useTCPOnlyCheckboxClicked(_ sender: Any) {
        let isUseTCPOnlyChecked = (useTCPOnlyCheckbox.state == .on)
        UserDefaults.standard.forceTCP = isUseTCPOnlyChecked
    }

    @IBAction func assistPathUpgradingCheckboxClicked(_ sender: Any) {
        let isChecked = (assistPathUpgradingCheckbox.state == .on)
        UserDefaults.standard.assistPathUpgradingWithPathMonitor = isChecked
    }

    @IBAction func viewLogClicked(_ sender: Any) {
        let connectionService = parameters.environment.connectionService
        guard connectionService.isInitialized else { return }
        firstly {
            connectionService.getConnectionLog()
        }.map { log in
            try self.showLog(log)
        }.catch { error in
            self.parameters.environment.navigationController?.showAlert(for: error)
        }
    }

    @IBAction func doneClicked(_ sender: Any) {
        self.presentingViewController?.dismiss(self)
    }
}

#if os(macOS)
private extension PreferencesViewController {
    @IBAction func showInStatusBarCheckboxClicked(_ sender: Any) {
        guard let appDelegate = NSApp.delegate as? AppDelegate else { return }
        let isChecked = (showInStatusBarCheckbox.state == .on)

        // If "Show in status bar" is unchecked, disable changing "Show in dock"
        showInDockCheckbox.isEnabled = isChecked

        appDelegate.setShowInStatusBarEnabled(isChecked)
        UserDefaults.standard.showInStatusBar = isChecked
    }

    @IBAction func showInDockCheckboxClicked(_ sender: Any) {
        guard let appDelegate = NSApp.delegate as? AppDelegate else { return }
        let isChecked = (showInDockCheckbox.state == .on)

        // If "Show in dock" is unchecked, disable changing "Show in status bar"
        showInStatusBarCheckbox.isEnabled = isChecked

        appDelegate.setShowInDockEnabled(isChecked)
        UserDefaults.standard.showInDock = isChecked
    }

    @IBAction func launchAtLoginCheckboxClicked(_ sender: Any) {
        guard let appDelegate = NSApp.delegate as? AppDelegate else { return }
        let isChecked = (launchAtLoginCheckbox.state == .on)

        appDelegate.setLaunchAtLoginEnabled(isChecked)
        UserDefaults.standard.launchAtLogin = isChecked
    }
}

private extension PreferencesViewController {
    private func showLog(_ log: String?) throws {
        let fileManager = FileManager.default
        guard let documentDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw PreferencesViewControllerError.cannotShowLog
        }
        guard let data = log?.data(using: .utf8) else {
            throw PreferencesViewControllerError.noLogAvailable
        }
        let tmpDir = documentDir.appendingPathComponent("tmp")
        let logPath = tmpDir.appendingPathComponent("connection.log")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        try data.write(to: logPath, options: [.atomic])
        NSWorkspace.shared.open(logPath)
    }
}
#endif
