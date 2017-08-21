//
//  SettingsViewController.swift
//  EduVPN
//
//  Created by Jeroen Leenarts on 14-08-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

import UIKit

protocol SettingsViewControllerDelegate: class {

}

class SettingsViewController: UIViewController {
    weak var delegate: SettingsViewControllerDelegate?
}

extension SettingsViewController: Identifyable {}
