//
//  showProfilesViewController.swift
//  eduVPN
//
//  Created by Jeroen Leenarts on 08-08-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

import UIKit

class ProfilesViewController: UIViewController {

    weak var delegate: ProfilesViewControllerDelegate?

    @IBOutlet weak var secureInternetView: UIView!
    @IBOutlet weak var settingsButton: UIBarButtonItem!
    
    func allowClose(_ state: Bool) {
    }
    
    private var allowClose = true {
        didSet {
            navigationItem?.hidesBackButton = !state
        }
    }
    
    func allowClose(_ state: Bool) {
        self.allowClose = state
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        (allowClose = allowClose)
    }

    @IBAction func didTapSecureAccess(_ sender: Any) {
        delegate?.profilesViewControllerDidSelectProviderType(profilesViewController: self,
                                                              providerType: .secureInternet)
    }

    @IBAction func didTapInstituteAccess(_ sender: Any) {
        delegate?.profilesViewControllerDidSelectProviderType(profilesViewController: self,
                                                              providerType: .instituteAccess)
    }

    @IBAction func didTapOtherAccess(_ sender: Any) {
        delegate?.profilesViewControllerDidSelectProviderType(profilesViewController: self,
                                                              providerType: .other)
    }

    @IBAction func settings(_ sender: Any) {
        delegate?.settings(profilesViewController: self)
    }
}
