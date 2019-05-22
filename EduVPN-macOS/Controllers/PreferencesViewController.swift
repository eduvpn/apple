//
//  PreferencesViewController.swift
//  eduVPN
//
//  Created by Johan Kool on 10/08/2017.
//  Copyright © 2017-2019 Commons Conservancy.
//

import Cocoa

class PreferencesViewController: NSViewController {

    @IBOutlet var launchAtLoginCheckbox: NSButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        launchAtLoginCheckbox.state = ServiceContainer.preferencesService.launchAtLogin ? .on : .off
    }
    
    @IBAction func toggleLaunchAtLogin(_ sender: NSButton) {
        ServiceContainer.preferencesService.launchAtLogin = sender.state == .on
    }
}
