//
//  showProfilesViewController.swift
//  EduVPN
//
//  Created by Jeroen Leenarts on 08-08-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

import UIKit

protocol ProfilesViewControllerDelegate: class {
    func profilesViewControllerDidSelectProviderType(profilesViewController: ProfilesViewController, providerType: ProviderType)
}

class ProfilesViewController: UIViewController {

    weak var delegate: ProfilesViewControllerDelegate?

    @IBAction func didTapSecureAccess(_ sender: Any) {
        self.delegate?.profilesViewControllerDidSelectProviderType(profilesViewController: self, providerType: .secureInternet)
    }

    @IBAction func didTapInstituteAccess(_ sender: Any) {
        self.delegate?.profilesViewControllerDidSelectProviderType(profilesViewController: self, providerType: .instituteAccess)
    }

    @IBAction func didTapOtherAccess(_ sender: Any) {
        self.delegate?.profilesViewControllerDidSelectProviderType(profilesViewController: self, providerType: .other)
    }
}

extension ProfilesViewController: Identifyable {}
