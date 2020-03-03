//
//  ProfilesViewController.swift
//  eduVPN
//

import UIKit

class ProfilesViewController: UIViewController {
    
    weak var delegate: ProfilesViewControllerDelegate?
    
    @IBOutlet weak var secureInternetView: UIView!
    @IBOutlet weak var settingsButton: UIBarButtonItem!
    
    private var allowClose = true {
        didSet {
            navigationItem.hidesBackButton = !allowClose
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
