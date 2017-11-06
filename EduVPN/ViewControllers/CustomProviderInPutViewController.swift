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
    @IBOutlet weak var bottomKeyboardConstraint: NSLayoutConstraint?

    fileprivate var keyboardWrapper: KeyboardWrapper?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        keyboardWrapper = KeyboardWrapper(delegate: self)
    }
}

extension CustomProviderInPutViewController: KeyboardWrapperDelegate {
    func keyboardWrapper(_ wrapper: KeyboardWrapper, didChangeKeyboardInfo info: KeyboardInfo) {
        if info.state == .willShow || info.state == .visible {
            bottomKeyboardConstraint?.constant = info.endFrame.size.height + 8.0
        } else {
            bottomKeyboardConstraint?.constant = 8.0
        }

        UIView.animate(withDuration: info.animationDuration, delay: 0.0, options: info.animationOptions, animations: { () -> Void in
            self.view.layoutIfNeeded()
        }, completion: nil)
    }
}

extension CustomProviderInPutViewController: Identifyable {}
