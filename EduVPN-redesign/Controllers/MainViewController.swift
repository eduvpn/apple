//
//  MainViewController.swift
//  EduVPN
//
//  Created by Johan Kool on 28/05/2020.
//  Copyright © 2020 SURFNet. All rights reserved.
//

import Foundation

protocol MainViewControllerDelegate: class {
    func mainViewControllerAddOtherServer(_ controller: MainViewController)
    func mainViewController(_ controller: MainViewController, connectToServer: AnyObject)
    func mainViewControllerChangeLocation(_ controller: MainViewController)
}

class MainViewController: ViewController {
    
    var viewModel: MainViewModel!
    weak var delegate: MainViewControllerDelegate?
    
    @IBOutlet private var addOtherServerButton: Button!
    @IBOutlet private var temporaryConnectButton: Button!
    
    @IBAction func addOtherServer(_ sender: Any) {
        delegate?.mainViewControllerAddOtherServer(self)
    }
    
    @IBAction func temporaryConnect(_ sender: Any) {
        delegate?.mainViewController(self, connectToServer: "Server Object" as AnyObject)
    }
}
