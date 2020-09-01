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

    func initializeParameters(_ parameters: Parameters) {
        guard self.parameters == nil else {
            fatalError("Can't initialize parameters twice")
        }
        self.parameters = parameters
    }

    override func viewDidLoad() {
        let isForceTCPEnabled = UserDefaults.standard.forceTCP
        useTCPOnlyCheckbox.state = isForceTCPEnabled ? .on : .off
    }

    @IBAction func useTCPOnlyCheckboxClicked(_ sender: Any) {
        let isUseTCPOnlyChecked = (useTCPOnlyCheckbox.state == .on)
        UserDefaults.standard.forceTCP = isUseTCPOnlyChecked
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
