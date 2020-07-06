//
//  SearchViewController.swift
//  EduVPN
//
//  Created by Johan Kool on 28/05/2020.
//

import Foundation

protocol SearchViewControllerDelegate: class {
    func searchViewControllerAddOtherServer(_ controller: SearchViewController)
    func searchViewController(_ controller: SearchViewController, selectedInstitute: AnyObject)
    func searchViewControllerCancelled(_ controller: SearchViewController)
}

class SearchViewController: ViewController {
    
    var viewModel: SearchViewModel!
    weak var delegate: SearchViewControllerDelegate?
    
    @IBOutlet private var cancelButton: Button!
    
    @IBAction func cancel(_ sender: Any) {
        delegate?.searchViewControllerCancelled(self)
    }
}
