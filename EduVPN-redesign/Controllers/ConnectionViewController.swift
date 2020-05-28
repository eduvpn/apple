//
//  ConnectionViewController.swift
//  EduVPN
//
//  Created by Johan Kool on 28/05/2020.
//  Copyright © 2020 SURFNet. All rights reserved.
//

import Foundation

protocol ConnectionViewControllerDelegate: class {
    func connectionViewControllerClosed(_ controller: ConnectionViewController)
}

class ConnectionViewController: ViewController {
    
    let viewModel: ConnectionViewModel
    weak var delegate: ConnectionViewControllerDelegate?
    
    init(viewModel: ConnectionViewModel, delegate: ConnectionViewControllerDelegate) {
        self.delegate = delegate
        self.viewModel = viewModel
        super.init(nibName: "Connection", bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
