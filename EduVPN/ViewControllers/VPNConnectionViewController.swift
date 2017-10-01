//
//  VPNConnectionViewController.swift
//  EduVPN
//
//  Created by Jeroen Leenarts on 24-09-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

import UIKit
protocol VPNConnectionViewControllerDelegate: class {
}

class VPNConnectionViewController: UIViewController {
    weak var delegate: VPNConnectionViewControllerDelegate?
}

extension VPNConnectionViewController: Identifyable {}
