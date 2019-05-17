//
//  AuthenticatingViewController.swift
//  eduVPN
//
//  Created by Johan Kool on 28/06/2017.
//  Copyright © 2017-2019 Commons Conservancy.
//

import Cocoa
import AppAuth

class AuthenticatingViewController: NSViewController {

    @IBOutlet var spinner: NSProgressIndicator!
    @IBOutlet var backButton: NSButton!
    
    override func viewWillAppear() {
        super.viewWillAppear()
        spinner.startAnimation(nil)
    }
    
    override func viewDidDisappear() {
        super.viewDidDisappear()
        spinner.stopAnimation(nil)
    }
    
    @IBAction func goBack(_ sender: Any) {
        ServiceContainer.authenticationService.cancelAuthentication()
    }
    
}
