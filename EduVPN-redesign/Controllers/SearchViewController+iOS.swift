//
//  SearchViewController+iOS.swift
//  EduVPN
//

import UIKit

extension SearchViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return numberOfRows()
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return cellForRow(at: indexPath.row, tableView: tableView)
    }

    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return canSelectRow(at: indexPath.row)
    }

    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        guard canSelectRow(at: indexPath.row) else { return nil }
        return indexPath
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        didSelectRow(at: indexPath.row)
        tableView.deselectRow(at: indexPath, animated: true)
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        let isHeaderRow = !canSelectRow(at: indexPath.row)
        return isHeaderRow ? 64 : 44
    }
}

extension SearchViewController: UISearchBarDelegate {
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        searchFieldGotFocus()
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange text: String) {
        self.searchFieldTextChanged(text: text)
    }
}

extension SearchViewController: AuthorizingViewController {
    func didBeginFetchingServerInfoForAuthorization(userCancellationHandler: (() -> Void)?) {
        let tableView = self.tableView
        let navigationController = self.navigationController as? NavigationController
        let cancelAction = UIAlertAction(
            title: NSLocalizedString("Cancel", comment: ""),
            style: .cancel,
            handler: { _ in
                userCancellationHandler?()
                tableView?.isUserInteractionEnabled = true
                navigationController?.isUserAllowedToGoBack = true
        })
        let alert = UIAlertController(title: NSLocalizedString("Contacting the server", comment: ""), message: nil, preferredStyle: .alert)
        alert.addAction(cancelAction)
        self.contactingServerAlert = alert

        tableView?.isUserInteractionEnabled = false
        navigationController?.isUserAllowedToGoBack = false

        present(alert, animated: true, completion: { })
    }

    func didBeginAuthorization(macUserCancellationHandler: (() -> Void)?) {
        self.contactingServerAlert?.dismiss(animated: true, completion: nil)
        self.contactingServerAlert = nil

        self.tableView?.isUserInteractionEnabled = false
        (navigationController as? NavigationController)?.isUserAllowedToGoBack = false
    }

    func didEndAuthorization() {
        self.contactingServerAlert = nil

        self.tableView?.isUserInteractionEnabled = true
        (navigationController as? NavigationController)?.isUserAllowedToGoBack = true
    }
}
