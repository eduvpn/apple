//
//  ServersViewController.swift
//  EduVPN
//
//  Created by Johan Kool on 02/04/2020.
//  Copyright © 2020 SURFNet. All rights reserved.
//

import UIKit
import CoreData

protocol ServersViewControllerDelegate: class {
    func serversViewControllerNoProfiles(_ controller: ServersViewController)
    func serversViewController(_ controller: ServersViewController, addProviderAnimated animated: Bool, allowClose: Bool)
    func serversViewControllerAddPredefinedProvider(_ controller: ServersViewController)
    func serversViewController(_ controller: ServersViewController, didSelect instance: Instance)
    func serversViewController(_ controller: ServersViewController, didDelete instance: Instance)
    func serversViewController(_ controller: ServersViewController, didDelete organization: Organization)
}

class ServersViewController: UIViewController {

    weak var delegate: ServersViewControllerDelegate?
    
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
