//
//  AddServerViewController+iOS.swift
//  EduVPN
//

import UIKit

extension AddServerViewController {
    @IBAction func addServerTapped(_ sender: Any) {
        serverURLTextField.resignFirstResponder()
        startAuth()
    }
}

extension AddServerViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        serverURLTextField.resignFirstResponder()
        startAuth()
        return true
    }
}

extension AddServerViewController: AuthorizingViewController {
    func didBeginFetchingServerInfoForAuthorization(userCancellationHandler: (() -> Void)?) {
        let cancelAction = UIAlertAction(
            title: NSLocalizedString("Cancel", comment: "button title"),
            style: .cancel,
            handler: { _ in
                userCancellationHandler?()
                self.isBusy = false
            })
        let alert = UIAlertController(
            title: NSLocalizedString(
                "Contacting the server",
                comment: "iOS: Alert text shown when initiating contact for adding a server"),
            message: nil,
            preferredStyle: .alert)
        alert.addAction(cancelAction)
        self.contactingServerAlert = alert
        self.isBusy = true

        present(alert, animated: true, completion: { })
    }

    func didBeginAuthorization(macUserCancellationHandler: (() -> Void)?) {
        self.contactingServerAlert?.dismiss(animated: true, completion: nil)
        self.contactingServerAlert = nil
        isBusy = true
    }

    func didEndAuthorization() {
        self.contactingServerAlert = nil
        isBusy = false
    }
}
