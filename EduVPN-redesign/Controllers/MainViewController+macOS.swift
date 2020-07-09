//
//  MainViewController+macOS.swift
//  EduVPN
//

import AppKit

extension MainViewController: NSTableViewDelegate, NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return numberOfRows()
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        return cellForRow(at: row, tableView: tableView)
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return canSelectRow(at: row)
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let tableView = notification.object as? NSTableView else { return }
        if let firstSelectedIndex = tableView.selectedRowIndexes.first {
            didSelectRow(at: firstSelectedIndex)
        }
        tableView.selectRowIndexes(IndexSet(), byExtendingSelection: false)
    }

    func tableView(_ tableView: NSTableView, rowActionsForRow row: Int,
                   edge: NSTableView.RowActionEdge) -> [NSTableViewRowAction] {
        guard canDeleteRow(at: row) else { return [] }
        let action = NSTableViewRowAction(
            style: .destructive,
            title: NSLocalizedString("Delete", comment: ""),
            handler: { _, index in
                self.deleteRow(at: index)
            })
        return [action]
    }
}
