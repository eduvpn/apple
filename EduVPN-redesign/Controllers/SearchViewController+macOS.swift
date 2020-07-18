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
        if let firstSelectedIndex = tableView.selectedRowIndexes.first {
            didSelectRow(at: firstSelectedIndex)
        }
        tableView.selectRowIndexes(IndexSet(), byExtendingSelection: false)
    }
}

extension SearchViewController {
    func performWithAnimation(seconds: TimeInterval, animationBlock: () -> Void) {
        NSAnimationContext.runAnimationGroup( { context in
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
