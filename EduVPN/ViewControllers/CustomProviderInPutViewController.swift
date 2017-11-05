//
//  CustomProviderInPutViewController.swift
//  EduVPN
//
//  Created by Jeroen Leenarts on 29-10-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

import UIKit

protocol CustomProviderInPutViewControllerDelegate: class {
}

class CustomProviderInPutViewController: UIViewController {
    weak var delegate: CustomProviderInPutViewControllerDelegate?
}

extension CustomProviderInPutViewController: Identifyable {}
