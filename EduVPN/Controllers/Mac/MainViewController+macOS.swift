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
        guard shouldPerformActionOnSelection else { return }
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

extension MainViewController: MenuCommandRespondingViewController {
    func canGoNextServer() -> Bool {
        tableView.selectedRow < (numberOfRows() - 1)
    }

    func goNextServer() {
        var currentRow = tableView.selectedRow + 1
        while !canSelectRow(at: currentRow) && currentRow < numberOfRows() {
            currentRow += 1
        }
        if canSelectRow(at: currentRow) {
            shouldPerformActionOnSelection = false
            tableView.selectRowIndexes([currentRow], byExtendingSelection: false)
            shouldPerformActionOnSelection = true
        }
    }

    func canGoPreviousServer() -> Bool {
        tableView.selectedRow > 1 || canSelectRow(at: 0)
    }

    func goPreviousServer() {
        var currentRow = tableView.selectedRow - 1
        while !canSelectRow(at: currentRow) && currentRow >= 0 {
            currentRow -= 1
        }
        if canSelectRow(at: currentRow) {
            shouldPerformActionOnSelection = false
            tableView.selectRowIndexes([currentRow], byExtendingSelection: false)
            shouldPerformActionOnSelection = true
        }
    }

    func actionMenuItemTitle() -> String {
        return "Begin Connecting"
    }

    func canPerformActionOnServer() -> Bool {
        let currentRow = tableView.selectedRow
        guard currentRow >= 0 && currentRow < numberOfRows() else {
            return false
        }
        return canSelectRow(at: tableView.selectedRow)
    }

    func performActionOnServer() {
        let currentRow = tableView.selectedRow
        guard currentRow >= 0 && currentRow < numberOfRows() else {
            return
        }
        if canSelectRow(at: currentRow) {
            didSelectRow(at: currentRow)
            tableView.selectRowIndexes([], byExtendingSelection: false)
        }
    }

    func canDeleteServer() -> Bool {
        let currentRow = tableView.selectedRow
        guard currentRow >= 0 && currentRow < numberOfRows() else {
            return false
        }
        return canDeleteRow(at: currentRow)
    }

    func deleteServer() {
        let currentRow = tableView.selectedRow
        guard currentRow >= 0 && currentRow < numberOfRows() else {
            return
        }
        if canDeleteRow(at: currentRow) {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = NSLocalizedString(
                "Are you sure you want to delete server “\(displayText(at: currentRow))”?",
                comment: "macOS alert title to confirm deletion of added server from menu")
            alert.addButton(withTitle: NSLocalizedString(
                                "Delete",
                                comment: "macOS alert button to confirm deletion of added server from menu"))
            alert.addButton(withTitle: NSLocalizedString(
                                "Cancel",
                                comment: "macOS alert button to confirm deletion of added server from menu"))
            if let window = NSApp.windows.first {
                alert.beginSheetModal(for: window) { result in
                    if case .alertFirstButtonReturn = result {
                        self.deleteRow(at: currentRow)
                    }
                }
            } else {
                let result = alert.runModal()
                if case .alertFirstButtonReturn = result {
                    self.deleteRow(at: currentRow)
                }
            }
        }
    }

    func canToggleVPN() -> Bool {
        return false
    }

    func toggleVPN() {
        // Can't toggle VPN while in main screen
    }

    func canRenewSession() -> Bool {
        return false
    }

    func renewSession() {
        // Can't renew session while in main screen
    }

    func canGoBackToServerList() -> Bool {
        return false
    }

    func goBackToServerList() {
        // Can't go back to server list while in main screen
    }
}
