//
//  SearchViewController.swift
//  EduVPN
//
//  Created by Johan Kool on 28/05/2020.
//  Copyright © 2020 SURFNet. All rights reserved.
//

import Foundation

protocol SearchViewControllerDelegate: class {
    func searchViewControllerAddOtherServer(_ controller: SearchViewController)
    func searchViewController(_ controller: SearchViewController, selectedInstitute: AnyObject)
    func searchViewControllerCancelled(_ controller: SearchViewController)
}

final class SearchViewController: ViewController, ParametrizedViewController {
    struct Parameters {
        let environment: Environment
    }

    weak var delegate: SearchViewControllerDelegate?

    private var parameters: Parameters!
    private var viewModel: SearchViewModel!

    @IBOutlet weak var tableView: NSTableView!

    func initializeParameters(_ parameters: Parameters) {
        guard self.parameters == nil else {
            fatalError("Can't initialize parameters twice")
        }
        self.parameters = parameters
        let viewModel = SearchViewModel(
            serverDiscoveryService: parameters.environment.serverDiscoveryService,
            scope: .all)
        viewModel.delegate = self
        self.viewModel = viewModel
    }
}

// MARK: - Search field

extension SearchViewController {
    @IBAction func searchFieldTextChanged(_ sender: Any) {
        if let searchField = sender as? NSSearchField {
            viewModel.setSearchQuery(searchField.stringValue)
        }
    }
}

// MARK: - Table view delegate and data source

extension SearchViewController {
    func numberOfRows() -> Int {
        return viewModel?.numberOfRows() ?? 0
    }

    func cellForRow(at index: Int, tableView: TableView) -> NSView? {
        let row = viewModel.row(at: index)
        if row.rowKind.isSectionHeader {
            let cell = tableView.dequeue(SectionHeaderCell.self,
                                         identifier: "SearchSectionHeaderCell",
                                         indexPath: IndexPath(item: index, section: 0))
            cell.configure(as: row.rowKind)
            return cell
        } else {
            let cell = tableView.dequeue(RowCell.self,
                                         identifier: "SearchRowCell",
                                         indexPath: IndexPath(item: index, section: 0))
            cell.configure(with: row)
            return cell
        }
    }

    func canSelectRow(at index: Int) -> Bool {
        return !viewModel.row(at: index).rowKind.isSectionHeader
    }
}

// MARK: - View model delegate

extension SearchViewController: SearchViewModelDelegate {
    func rowsChanged(changes: RowsDifference<SearchViewModel.Row>) {
        guard let tableView = tableView else { return }
        tableView.beginUpdates()
        tableView.removeRows(at: IndexSet(changes.deletedIndices),
                             withAnimation: [])
        tableView.insertRows(at: IndexSet(changes.insertions.map { $0.0 }),
                             withAnimation: [])
        tableView.endUpdates()
    }
}
