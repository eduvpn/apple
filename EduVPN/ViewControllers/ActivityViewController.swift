//
//  ActivityViewController.swift
//  EduVPN
//
//  Created by Jeroen Leenarts on 29/11/2019.
//  Copyright © 2019 SURFNet. All rights reserved.
//

import UIKit

class ActivityViewController: UIViewController {
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var infoLabel: UILabel!
}

extension ActivityViewController: Identifiable {}
