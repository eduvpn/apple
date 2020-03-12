//
//  ProfilesViewController.swift
//  eduVPN
//

import UIKit

protocol ProfilesViewControllerDelegate: class {
    
    func profilesViewControllerDidSelectProviderType(_ controller: ProfilesViewController, providerType: ProviderType)
    func profilesViewControllerShowSettings(_ controller: ProfilesViewController)
    
}

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
        delegate?.profilesViewControllerDidSelectProviderType(self, providerType: .secureInternet)
    }
    
    @IBAction func didTapInstituteAccess(_ sender: Any) {
        delegate?.profilesViewControllerDidSelectProviderType(self, providerType: .instituteAccess)
    }
    
    @IBAction func didTapOtherAccess(_ sender: Any) {
        delegate?.profilesViewControllerDidSelectProviderType(self, providerType: .other)
    }
    
    @IBAction func settings(_ sender: Any) {
        delegate?.profilesViewControllerShowSettings(self)
    }
}
