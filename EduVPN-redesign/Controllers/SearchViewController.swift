//
//  SearchViewController.swift
//  EduVPN
//
//  Created by Johan Kool on 28/05/2020.
//  Copyright © 2020 SURFNet. All rights reserved.
//

import Foundation

protocol SearchViewControllerDelegate: class {
    func searchViewControllerAddOtherServer(_ controller: SearchViewController)
    func searchViewController(_ controller: SearchViewController, selectedInstitute: AnyObject)
    func searchViewControllerCancelled(_ controller: SearchViewController)
}

class SearchViewController: ViewController {
    
    let viewModel: SearchViewModel
    weak var delegate: SearchViewControllerDelegate?
    
    init(viewModel: SearchViewModel, delegate: SearchViewControllerDelegate) {
        self.delegate = delegate
        self.viewModel = viewModel
        super.init(nibName: "Search", bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
