//
//  SystemExtensionHelper.swift
//  EduVPN
//

#if DEVELOPER_ID_DISTRIBUTION

import Foundation
import SystemExtensions

enum SystemExtensionHelperError: String, Error {
    case rebootRequiredError = "Reboot required"
    case unknownError = "Unknown error"
}

class SystemExtensionHelper: NSObject {
    var alertAskingToEnableSystemExtensions: NSAlert?

    func beginSystemExtensionInstallation() {
        NSLog("beginSystemExtensionInstallation")
        guard let appId = Bundle.main.bundleIdentifier else { fatalError("missing bundle id") }
        let tunnelExtensionBundleId = "\(appId).TunnelExtension"
        let request = OSSystemExtensionRequest.activationRequest(
            forExtensionWithIdentifier: tunnelExtensionBundleId,
            queue: DispatchQueue.main)
        request.delegate = self
        OSSystemExtensionManager.shared.submitRequest(request)
    }
}

extension SystemExtensionHelper: OSSystemExtensionRequestDelegate {
    func request(_ request: OSSystemExtensionRequest, actionForReplacingExtension existing: OSSystemExtensionProperties, withExtension ext: OSSystemExtensionProperties) -> OSSystemExtensionRequest.ReplacementAction {
        NSLog("System Extension: Replacing \(existing.bundleShortVersion) with \(ext.bundleShortVersion)")
        return .replace
    }

    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        NSLog("System Extension: Needs user approval")
        showAlertAskingToEnableSystemExtensions()
    }

    func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
        if result == .completed {
            NSLog("System Extension: Loading complete")
            hideAlertAskingToEnableSystemExtensions()
        } else if result == .willCompleteAfterReboot {
            NSLog("System Extension: Loading requires reboot")
            showAlertOnSystemExtensionError(error: SystemExtensionHelperError.rebootRequiredError)
        } else {
            NSLog("System Extension: OSSystemExtensionRequest code = \(result.rawValue)")
            showAlertOnSystemExtensionError(error: SystemExtensionHelperError.unknownError)
        }
    }

    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        NSLog("System Extension: Error: \(error)")
        showAlertOnSystemExtensionError(error: error)
    }
}

private extension SystemExtensionHelper {
    func showAlertAskingToEnableSystemExtensions() {
        let alert = NSAlert()
        alert.alertStyle = .critical

        alert.messageText = NSLocalizedString(
            "Allow application to load system software",
            comment: "macOS alert title on attempt to install System Extension")
        alert.informativeText = String(
            format: NSLocalizedString(
                "This application can work only after you enable it to install System Extensions.\n\nOpen Security Settings (Settings > Privacy & Security > Security), look for a message saying that system software from \"%@\" was blocked, and click on \"Allow\" next to that.",
                comment: "macOS alert text on attempt to install System Extension"),
            Config.shared.appName)
        let openSettingsButton = alert.addButton(withTitle: NSLocalizedString(
            "Open Settings",
            comment: "macOS alert button on attempt to install System Extension"))
        openSettingsButton.target = self
        openSettingsButton.action = #selector(openSecurityPreferencesPane)

        alert.addButton(withTitle: NSLocalizedString("Quit", comment: ""))

        alertAskingToEnableSystemExtensions = alert

        if let window = NSApp.windows.first {
            alert.beginSheetModal(for: window) { result in
                if case .alertSecondButtonReturn = result {
                    NSApp.terminate(self)
                }
            }
        }
    }

    @objc func openSecurityPreferencesPane() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Security") {
            NSWorkspace.shared.open(url)
        }
    }

    func hideAlertAskingToEnableSystemExtensions() {
        if let alert = alertAskingToEnableSystemExtensions,
           let window = NSApp.windows.first {
            window.endSheet(alert.window)
        }
    }

    func showAlertOnSystemExtensionError(error: Error) {

        hideAlertAskingToEnableSystemExtensions()

        let alert = NSAlert()
        alert.alertStyle = .critical

        alert.messageText = NSLocalizedString(
            "Error installing System Extension",
            comment: "macOS alert title on failure to install System Extension")
        alert.informativeText = String(
            format: NSLocalizedString(
                "Unable to install System Extension.\nError: %@",
                comment: "macOS alert text on failure to install System Extension"),
            error.localizedDescription)
        alert.addButton(withTitle: NSLocalizedString(
            "Try Again",
            comment: "macOS alert button on attempt to install System Extension"))
        alert.addButton(withTitle: NSLocalizedString("Quit", comment: ""))

        if let window = NSApp.windows.first {
            alert.beginSheetModal(for: window) { [weak self] result in
                if case .alertFirstButtonReturn = result {
                    self?.beginSystemExtensionInstallation()
                } else if case .alertSecondButtonReturn = result {
                    NSApp.terminate(self)
                }
            }
        }
    }
}

#endif
