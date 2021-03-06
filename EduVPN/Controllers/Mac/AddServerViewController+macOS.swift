//
//  AddServerViewController+macOS.swift
//  EduVPN
//

import AppKit

extension AddServerViewController {
    @IBAction func addServerClicked(_ sender: Any) {
        startAuth()
    }

    @IBAction func serverURLTextFieldReturnPressed(_ sender: Any) {
        startAuth()
    }
}

extension AddServerViewController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        onServerURLTextFieldTextChanged()
    }
}

extension AddServerViewController: AuthorizingViewController {
    func didBeginFetchingServerInfoForAuthorization(userCancellationHandler: (() -> Void)?) {
        navigationController?.showAuthorizingMessage(onCancelled: userCancellationHandler)
    }

    func didBeginAuthorization(macUserCancellationHandler: (() -> Void)?) {
        navigationController?.showAuthorizingMessage(onCancelled: macUserCancellationHandler)
    }

    func didEndAuthorization() {
        navigationController?.hideAuthorizingMessage()
        NSApp.activate(ignoringOtherApps: true)
    }
}
