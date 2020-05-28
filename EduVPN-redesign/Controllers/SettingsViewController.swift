//
//  SettingsViewController.swift
//  EduVPN
//
//  Created by Johan Kool on 28/05/2020.
//  Copyright © 2020 SURFNet. All rights reserved.
//

import Foundation

protocol SettingsViewControllerDelegate: class {
    func settingsViewControllerClosed(_ controller: SettingsViewController)
}

class SettingsViewController: ViewController {
    
    let viewModel: SettingsViewModel
    weak var delegate: SettingsViewControllerDelegate?
    
    init(viewModel: SettingsViewModel, delegate: SettingsViewControllerDelegate) {
        self.delegate = delegate
        self.viewModel = viewModel
        super.init(nibName: "Settings", bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
