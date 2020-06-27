//
//  SearchViewController.swift
//  EduVPN
//
//  Created by Johan Kool on 28/05/2020.
//

import Foundation
import PromiseKit
import AppAuth

protocol SearchViewControllerDelegate: class {
    func searchViewControllerAddedServer(baseURL: URL, authState: AuthState)
}

final class SearchViewController: ViewController, ParametrizedViewController {
    struct Parameters {
        let environment: Environment
    }

    weak var delegate: SearchViewControllerDelegate?

    private var parameters: Parameters!
    private var viewModel: SearchViewModel!

    @IBOutlet weak var stackView: NSStackView!
    @IBOutlet weak var topSpacerView: NSView!
    @IBOutlet weak var topImageView: NSImageView!
    @IBOutlet weak var tableContainerView: NSScrollView!
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var spinner: NSProgressIndicator!

    private var isTableViewShown: Bool = false

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

    override func viewDidLoad() {
        spinner.layer?.opacity = 0
        tableContainerView.layer?.opacity = 0
    }

    func showTableView() {
        if isTableViewShown {
            return
        }
        isTableViewShown = true
        for view in [topSpacerView, topImageView] {
            view?.removeFromSuperview()
        }
        NSAnimationContext.runAnimationGroup({context in
            context.duration = 0.5
            context.allowsImplicitAnimation = true
            spinner.layer?.opacity = 1
            tableContainerView.layer?.opacity = 1
            stackView.layoutSubtreeIfNeeded()
        }, completionHandler: nil)
        spinner.startAnimation(self)
        firstly {
            self.viewModel.load(from: .cache)
        }.then {
            self.viewModel.load(from: .server)
        }.ensure {
            self.spinner.stopAnimation(self)
            self.spinner.removeFromSuperview()
        }.catch { error in
            NSLog("Error: \(error.localizedDescription)")
        }
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

extension SearchViewController {
    func searchFieldGotFocus() {
        showTableView()
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
        } else if row.rowKind == .noResultsKind {
            let cell = tableView.dequeue(SearchNoResultsCell.self,
                                         identifier: "SearchNoResultsCell",
                                         indexPath: IndexPath(item: index, section: 0))
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
        return viewModel.row(at: index).rowKind.isServerRow
    }

    func didSelectRow(at index: Int) {
        let row = viewModel.row(at: index)
        let serverAuthService = parameters.environment.serverAuthService
        let navigationController = parameters.environment.navigationController
        let delegate = self.delegate
        if let baseURL = row.baseURL {
            navigationController?.showAuthorizingMessage(cancelAuthorizationHandler: {
                serverAuthService.cancelAuth()
                navigationController?.hideAuthorizingMessage()
            })
            firstly {
                serverAuthService.startAuth(baseURL: baseURL, from: self)
            }.ensure {
                makeApplicationComeToTheForeground()
                navigationController?.hideAuthorizingMessage()
            }.map { authState in
                delegate?.searchViewControllerAddedServer(baseURL: baseURL, authState: authState)
                navigationController?.popViewController(animated: true)
            }.catch { error in
                print("Error: \(error)")
            }
        }
    }
}

private func makeApplicationComeToTheForeground() {
    NSApp.activate(ignoringOtherApps: true)
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

class SearchNoResultsCell: TableViewCell {
}
