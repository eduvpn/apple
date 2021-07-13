//
//  SearchViewController+macOS.swift
//  EduVPN
//

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

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let tableView = notification.object as? NSTableView else { return }
        guard shouldPerformActionOnSelection else { return }
        if let firstSelectedIndex = tableView.selectedRowIndexes.first {
            didSelectRow(at: firstSelectedIndex)
        }
        tableView.selectRowIndexes(IndexSet(), byExtendingSelection: false)
    }
}

extension SearchViewController {
    func performWithAnimation(seconds: TimeInterval, animationBlock: () -> Void) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = seconds
            context.allowsImplicitAnimation = true
            animationBlock()
        }, completionHandler: nil)
    }
}

extension SearchViewController {
    @IBAction func searchFieldTextChanged(_ sender: Any) {
        if let searchField = sender as? NSSearchField {
            self.searchFieldTextChanged(text: searchField.stringValue)
        }
    }
}

class SearchField: NSSearchField {
    override func becomeFirstResponder() -> Bool {
        // Walk the responder chain to find SearchViewController
        var responder: NSResponder? = nextResponder
        while responder != nil {
            if let searchVC = responder as? SearchViewController {
                searchVC.searchFieldGotFocus()
                break
            }
            responder = responder?.nextResponder
        }
        return super.becomeFirstResponder()
    }
}

extension SearchViewController {
    static func makeApplicationComeToTheForeground() {
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension SearchViewController: AuthorizingViewController {
    func didBeginFetchingServerInfoForAuthorization(userCancellationHandler: (() -> Void)?) {
        navigationController?.showAuthorizingMessage(onCancelled: userCancellationHandler)
    }

    func didBeginAuthorization(macUserCancellationHandler: (() -> Void)?) {
        navigationController?.showAuthorizingMessage(onCancelled: macUserCancellationHandler)
    }

    func didEndAuthorization() {
        navigationController?.hideAuthorizingMessage()
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension SearchViewController: MenuCommandResponding {
    func canGoNextServer() -> Bool {
        guard hasResults() else {
            return false
        }
        guard tableView.selectedRow >= 0 else {
            return numberOfRows() > 0
        }
        return tableView.selectedRow < (numberOfRows() - 1)
    }

    func goNextServer() {
        var currentRow = tableView.selectedRow + 1
        while currentRow < numberOfRows() && !canSelectRow(at: currentRow) {
            currentRow += 1
        }
        if canSelectRow(at: currentRow) {
            shouldPerformActionOnSelection = false
            tableView.selectRowIndexes([currentRow], byExtendingSelection: false)
            tableView.scrollRowToVisible(currentRow)
            shouldPerformActionOnSelection = true
        }
    }

    func canGoPreviousServer() -> Bool {
        guard hasResults() && tableView.selectedRow > 0 else {
            return false
        }
        return tableView.selectedRow > 1 || canSelectRow(at: tableView.selectedRow - 1)
    }

    func goPreviousServer() {
        var currentRow = tableView.selectedRow - 1
        while !canSelectRow(at: currentRow) && currentRow >= 0 {
            currentRow -= 1
        }
        if canSelectRow(at: currentRow) {
            shouldPerformActionOnSelection = false
            tableView.selectRowIndexes([currentRow], byExtendingSelection: false)
            tableView.scrollRowToVisible(currentRow)
            shouldPerformActionOnSelection = true
        }
    }

    func actionMenuItemTitle() -> String {
        return "Add Server..."
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

    func canGoBackToServerList() -> Bool {
        return hasAddedServers && !isBusy
    }

    func goBackToServerList() {
        navigationController?.popViewController(animated: true)
    }
}
