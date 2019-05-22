//
//  ChooseProviderViewController.swift
//  eduVPN
//
//  Created by Johan Kool on 28/06/2017.
//  Copyright © 2017-2019 Commons Conservancy.
//

import Cocoa
import Kingfisher

class ChooseProviderViewController: NSViewController {

    @IBOutlet var tableView: NSTableView!
    @IBOutlet var backButton: NSButton!
    
    var connectionType: ConnectionType!
    var providers: [Provider] = []
    
    override func viewDidAppear() {
        super.viewDidAppear()
        tableView.deselectAll(nil)
        tableView.isEnabled = true
    }
    
    @IBAction func goBack(_ sender: Any) {
        mainWindowController?.pop()
    }
}

extension ChooseProviderViewController: NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return providers.count
    }
}

extension ChooseProviderViewController: NSTableViewDelegate {
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let result = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "ProviderCell"),
                                        owner: self)
        
        if let cellView = result as? NSTableCellView {
            cellView.imageView?.kf.setImage(with: providers[row].logoURL)
            cellView.textField?.stringValue = providers[row].displayName
        }
        
        return result
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        guard tableView.selectedRow >= 0 else {
            return
        }
        
        tableView.isEnabled = false
        ServiceContainer.providerService.fetchInfo(for: providers[tableView.selectedRow]) { result in
            switch result {
            case .success(let info):
                DispatchQueue.main.async {
                    self.authenticate(with: info)
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    NSAlert(customizedError: error)?.beginSheetModal(for: self.view.window!) { _ in
                        self.tableView.isEnabled = true
                    }
                }
            }
        }
    }
    
    private func authenticate(with info: ProviderInfo) {
        ServiceContainer.authenticationService.authenticate(using: info) { (result) in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    ServiceContainer.providerService.storeProvider(provider: info.provider)
                    self.mainWindowController?.dismiss()
                case .failure(let error):
                    NSAlert(customizedError: error)?.beginSheetModal(for: self.view.window!)
                }
            }
        }
    }
}
