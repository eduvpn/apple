//
//  ChooseProfileViewController.swift
//  eduVPN
//
//  Created by Johan Kool on 07/07/2017.
//  Copyright © 2017-2019 Commons Conservancy.
//

import Cocoa
import AppAuth

class ChooseProfileViewController: NSViewController {

    @IBOutlet var tableView: NSTableView!
    @IBOutlet var backButton: NSButton!
    
    var userInfo: UserInfo!
    var profiles: [Profile]!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        tableView.deselectAll(nil)
        tableView.isEnabled = true
    }
    
    @IBAction func goBack(_ sender: Any) {
        mainWindowController?.pop()
    }
    
}

extension ChooseProfileViewController: NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return profiles.count
    }
    
}

extension ChooseProfileViewController: NSTableViewDelegate {
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let result = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "ProfileCell"), owner: self) as? NSTableCellView
        result?.textField?.stringValue = profiles[row].displayName
        return result
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        guard tableView.selectedRow >= 0 else {
            return
        }
        
        tableView.isEnabled = false
        
        let profile = profiles[tableView.selectedRow]
        mainWindowController?.showConnection(for: profile, userInfo: userInfo)
    }
    
}
