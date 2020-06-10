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
    
//    init(viewModel: MainViewModel, delegate: MainViewControllerDelegate) {
//        self.delegate = delegate
//        self.viewModel = viewModel
//        super.init(nibName: "Main", bundle: nil)
//    }
    
//    required init?(coder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
    
}
