//
//  ProfilesViewController.swift
//  eduVPN
//

import Cocoa

protocol ProfilesViewControllerDelegate: class {
    
    func profilesViewControllerDidSelectProviderType(_ controller: ProfilesViewController, providerType: ProviderType)
    func profilesViewControllerWantsToClose(_ controller: ProfilesViewController)
    func profilesViewControllerWantsToAddUrl(_ controller: ProfilesViewController)
    func profilesViewControllerWantsChooseConfigFile(_ controller: ProfilesViewController)
    func profilesViewControllerApiDiscoveryEnabled(_ controller: ProfilesViewController) -> Bool
    
}

/// This screen lets the user choose what type of provider to add. It uses the same name as iOS, but has a confusing name.
class ProfilesViewController: NSViewController {
    
    weak var delegate: ProfilesViewControllerDelegate?
    
    @IBOutlet var imageView: NSImageView!
    @IBOutlet var secureInternetButton: NSButton!
    @IBOutlet var instituteAccessButton: NSButton!
    @IBOutlet var closeButton: NSButton!
    @IBOutlet var enterProviderButton: NSButton!
    @IBOutlet var chooseConfigFileButton: NSButton!
    
    private var allowClose = true {
        didSet {
            guard isViewLoaded else {
                return
            }
            closeButton?.isHidden = !allowClose
        }
    }
    
    func allowClose(_ state: Bool) {
        self.allowClose = state
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        (allowClose = allowClose)
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        secureInternetButton.isEnabled = true
        instituteAccessButton.isEnabled = true
        
        let apiDiscoveryEnabled = delegate?.profilesViewControllerApiDiscoveryEnabled(self) ?? false
        
        secureInternetButton.isHidden = !apiDiscoveryEnabled
        instituteAccessButton.isHidden = !apiDiscoveryEnabled
        
        imageView.isHidden = apiDiscoveryEnabled
    }
    
    @IBAction func chooseSecureInternet(_ sender: Any) {
        delegate?.profilesViewControllerDidSelectProviderType(self, providerType: .secureInternet)
    }
    
    @IBAction func chooseInstituteAccess(_ sender: Any) {
        delegate?.profilesViewControllerDidSelectProviderType(self, providerType: .instituteAccess)
    }
    
    @IBAction func close(_ sender: Any) {
        delegate?.profilesViewControllerWantsToClose(self)
    }
    
    @IBAction func enterProviderURL(_ sender: Any) {
        delegate?.profilesViewControllerWantsToAddUrl(self)
    }
    
    @IBAction func chooseConfigFile(_ sender: Any) {
        delegate?.profilesViewControllerWantsChooseConfigFile(self)
    }
}
