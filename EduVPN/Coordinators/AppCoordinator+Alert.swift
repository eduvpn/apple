//
//  AppCoordinator+Alert.swift
//  EduVPN
//
//  Created by Jeroen Leenarts on 09-06-18.
//  Copyright © 2018 SURFNet. All rights reserved.
//

import UIKit

extension AppCoordinator {

    public func showError(_ error: Error) {
        showAlert(title: NSLocalizedString("Error", comment: "Error alert title"), message: error.localizedDescription)
    }

    func showNoProfilesAlert() {
        showAlert(title: NSLocalizedString("No profiles available", comment: "No profiles available title"), message: NSLocalizedString("There are no profiles configured for you on the instance you selected.", comment: "No profiles available message"))
    }

    func showNoOpenVPNAlert() {
        showAlert(title: NSLocalizedString("OpenVPN Connect app", comment: "No OpenVPN available title"), message: NSLocalizedString("The OpenVPN Connect app is required to use EduVPN.", comment: "No OpenVPN available message"))
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK button"), style: .default))
        self.navigationController.present(alert, animated: true)
    }
}
