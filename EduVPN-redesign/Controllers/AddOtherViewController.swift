//
//  AddOtherViewController.swift
//  EduVPN
//
//  Created by Johan Kool on 28/05/2020.
//

import Foundation

protocol AddOtherViewControllerDelegate: class {
    func addOtherViewController(_ controller: AddOtherViewController, addedServer: AnyObject)
    func addOtherViewControllerCancelled(_ controller: AddOtherViewController)
}

class AddOtherViewController: ViewController {
    
    let viewModel: AddOtherViewModel
    weak var delegate: AddOtherViewControllerDelegate?
    
    init(viewModel: AddOtherViewModel, delegate: AddOtherViewControllerDelegate) {
        self.delegate = delegate
        self.viewModel = viewModel
        super.init(nibName: "AddOther", bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
