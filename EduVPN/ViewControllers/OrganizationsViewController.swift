//
//  OrganizationsViewController.swift
//  EduVPN
//
//  Created by Johan Kool on 02/04/2020.
//  Copyright © 2020 SURFNet. All rights reserved.
//

import UIKit
import CoreData

protocol OrganizationsViewControllerDelegate: class {
    func organizationsViewController(_ controller: OrganizationsViewController, didSelect instance: Organization)
    func organizationsViewControllerShouldClose(_ controller: OrganizationsViewController)
    func organizationsViewControllerWantsToAddUrl(_ controller: OrganizationsViewController)
}

/// Used to display and search all available organizations and to select a specific organization to add.
class OrganizationsViewController: UITableViewController {
    
    weak var delegate: OrganizationsViewControllerDelegate?
    
    private var allowClose = true {
        didSet {
            guard isViewLoaded else {
                return
            }
//            backButton?.isHidden = !allowClose
        }
    }
    
    func allowClose(_ state: Bool) {
        self.allowClose = state
    }
        
    var viewContext: NSManagedObjectContext!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
