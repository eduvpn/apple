//
//  ProfilesViewController.swift
//  eduVPN
//
//  Created by Johan Kool on 06/07/2017.
//  Copyright © 2017-2019 Commons Conservancy.
//

import Cocoa

class ProfilesViewController: NSViewController {
    
    weak var delegate: ProfilesViewControllerDelegate?

    @IBOutlet var secureInternetButton: NSButton!
    @IBOutlet var instituteAccessButton: NSButton!
    @IBOutlet var closeButton: NSButton!
    @IBOutlet var enterProviderButton: NSButton!
    @IBOutlet var chooseConfigFileButton: NSButton!
    
    private var allowClose = true {
        didSet {
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
        
        secureInternetButton.isHidden = !Config.shared.apiDiscoveryEnabled
        instituteAccessButton.isHidden = !Config.shared.apiDiscoveryEnabled
    }
    
    @IBAction func chooseSecureInternet(_ sender: Any) {
        delegate?.profilesViewControllerDidSelectProviderType(profilesViewController: self,
                                                              providerType: .secureInternet)
    }
   
    @IBAction func chooseInstituteAccess(_ sender: Any) {
        delegate?.profilesViewControllerDidSelectProviderType(profilesViewController: self,
                                                              providerType: .instituteAccess)
    }
    
    @IBAction func close(_ sender: Any) {
        mainWindowController?.dismiss()
    }
    
    @IBAction func enterProviderURL(_ sender: Any) {
        delegate?.profilesViewControllerWantsToAddUrl()
    }
    
    @IBAction func chooseConfigFile(_ sender: Any) {
        delegate?.profilesViewControllerWantsChooseConfigFile()
    }
}
