//
//  TableViewShims.swift
//  EduVPN
//

// Provides a cross-platform interface for table view delegate and
// table view data source for simple table views.
// Does not support sections in iOS.
// Does not support multiple columns in macOS.

#if os(iOS)

#elseif os(macOS)
import AppKit

extension SearchViewController: NSTableViewDelegate, NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return numberOfRows()
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        return cellForRow(at: row, tableView: tableView)
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return canSelectRow(at: row)
    }
}

#endif
