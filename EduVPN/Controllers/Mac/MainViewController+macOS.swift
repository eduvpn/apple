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
            style: .regular,
            title: NSLocalizedString("Delete", comment: "Main screen: Delete server"),
            handler: { _, index in
                self.deleteRow(at: index)
            })
        action.backgroundColor = NSColor.systemRed
        return [action]
    }
}

extension MainViewController: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let index = tableView.clickedRow
        guard index >= 0 && index < numberOfRows() else { return }
        if canDeleteRow(at: index) {
            let serverNameItem = NSMenuItem(title: displayText(at: index), action: nil, keyEquivalent: "")
            serverNameItem.isEnabled = false
            menu.addItem(serverNameItem)
            let deleteItem = NSMenuItem(title: "Delete", action: #selector(deleteMenuItemClicked(_:)), keyEquivalent: "")
            menu.addItem(deleteItem)
        }
    }
}

extension MainViewController {
    @objc func deleteMenuItemClicked(_ sender: Any) {
        let index = tableView.clickedRow
        self.deleteRow(at: index)
    }
}
