//
//  DeselectingTableView.swift
//  EduVPN-macOS
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
