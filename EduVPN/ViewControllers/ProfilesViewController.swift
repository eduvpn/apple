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
    func settings(profilesViewController: ProfilesViewController)
}

class ProfilesViewController: UIViewController {

    var showSecureInterNetOption: Bool = true {
        didSet {
            secureInternetView?.isHidden = !showSecureInterNetOption
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        secureInternetView.isHidden = !showSecureInterNetOption
    }

    weak var delegate: ProfilesViewControllerDelegate?

    @IBOutlet weak var secureInternetView: UIView!
    @IBOutlet weak var settingsButton: UIBarButtonItem!

    @IBAction func didTapSecureAccess(_ sender: Any) {
        self.delegate?.profilesViewControllerDidSelectProviderType(profilesViewController: self, providerType: .secureInternet)
    }
    
    @IBAction func didTapInstituteAccess(_ sender: Any) {
        self.delegate?.profilesViewControllerDidSelectProviderType(profilesViewController: self, providerType: .instituteAccess)
    }

    @IBAction func didTapOtherAccess(_ sender: Any) {
        self.delegate?.profilesViewControllerDidSelectProviderType(profilesViewController: self, providerType: .other)
    }

    @IBAction func settings(_ sender: Any) {
        delegate?.settings(profilesViewController: self)
    }
}

extension ProfilesViewController: Identifyable {}
