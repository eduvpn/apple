//
//  DeselectingTableView.swift
//  EduVPN-macOS
//
//  Created by Aleksandr Poddubny on 31/05/2019.
//  Copyright © 2020 SURFNet. All rights reserved.
//

import Cocoa

class DeselectingTableView: NSTableView {
    
    override open func mouseDown(with event: NSEvent) {
        let beforeIndex = selectedRow
        
        super.mouseDown(with: event)
        
        let point = convert(event.locationInWindow, from: nil)
        let rowIndex = row(at: point)
        
        if rowIndex < 0 {
            deselectAll(nil)
        } else if rowIndex == beforeIndex {
            deselectRow(rowIndex)
        } else if let delegate = delegate, let shouldSelectRow = delegate.tableView?(self, shouldSelectRow: rowIndex) {
            if !shouldSelectRow {
                deselectAll(nil)
            }
        }
    }
}
