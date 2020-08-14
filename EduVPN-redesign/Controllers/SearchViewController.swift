//
//  SearchViewController.swift
//  EduVPN
//

import Foundation
import PromiseKit
import AppAuth
import os.log

protocol SearchViewControllerDelegate: class {
    func searchViewControllerAddedSimpleServer(
        baseURLString: DiscoveryData.BaseURLString, authState: AuthState)
    func searchViewControllerAddedSecureInternetServer(
        baseURLString: DiscoveryData.BaseURLString, orgId: String, authState: AuthState)
}

final class SearchViewController: ViewController, ParametrizedViewController {
    struct Parameters {
        let environment: Environment
        let shouldIncludeOrganizations: Bool
    }

    weak var delegate: SearchViewControllerDelegate?

    private var parameters: Parameters!
    private var viewModel: SearchViewModel!

    @IBOutlet weak var stackView: StackView!
    @IBOutlet weak var topSpacerView: View!
    @IBOutlet weak var topImageView: ImageView!
    @IBOutlet weak var tableContainerView: View!
    @IBOutlet weak var tableView: TableView!
    @IBOutlet weak var spinner: ProgressIndicator!

    private var isTableViewShown: Bool = false

    func initializeParameters(_ parameters: Parameters) {
        guard self.parameters == nil else {
            fatalError("Can't initialize parameters twice")
        }
        self.parameters = parameters
        guard let serverDiscoveryService = parameters.environment.serverDiscoveryService else {
            fatalError("SearchViewController requires a valid ServerDiscoveryService instance")
        }
        let viewModel = SearchViewModel(
            serverDiscoveryService: serverDiscoveryService,
            shouldIncludeOrganizations: parameters.shouldIncludeOrganizations)
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
        performWithAnimation(seconds: 0.5) {
            spinner.layer?.opacity = 1
            tableContainerView.layer?.opacity = 1
            stackView.layoutSubtreeIfNeeded()
        }
        spinner.startAnimation(self)
        firstly {
            self.viewModel.load(from: .cache)
        }.recover { _ in
            // Ignore any errors loading from cache
        }.then {
            self.viewModel.load(from: .server)
        }.ensure {
            self.spinner.stopAnimation(self)
            self.spinner.removeFromSuperview()
        }.catch { error in
            os_log("Error loading discovery data for searching: %{public}@",
                   log: Log.general, type: .error,
                   error.localizedDescription)
            self.parameters.environment.navigationController?.showAlert(for: error)
        }
    }
}

// MARK: - Search field

extension SearchViewController {
    func searchFieldGotFocus() {
        showTableView()
    }

    func searchFieldTextChanged(text: String) {
        viewModel.setSearchQuery(text)
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
            cell.configure(as: row.rowKind, isAdding: true)
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
        if let baseURLString = row.baseURLString {
            firstly {
                serverAuthService.startAuth(baseURLString: baseURLString, from: self)
            }.map { authState in
                switch row {
                case .instituteAccessServer, .serverByURL:
                    delegate?.searchViewControllerAddedSimpleServer(baseURLString: baseURLString, authState: authState)
                case .secureInternetOrg(let organization):
                    delegate?.searchViewControllerAddedSecureInternetServer(baseURLString: baseURLString, orgId: organization.orgId, authState: authState)
                default:
                    break
                }
            }.catch { error in
                os_log("Error during authentication: %{public}@",
                       log: Log.general, type: .error,
                       error.localizedDescription)
                if !serverAuthService.isUserCancelledError(error) {
                    navigationController?.showAlert(for: error)
                }
            }
        }
    }
}

// MARK: - View model delegate

extension SearchViewController: SearchViewModelDelegate {
    func rowsChanged(changes: RowsDifference<SearchViewModel.Row>) {
        tableView?.performUpdates(deletedIndices: changes.deletedIndices,
                                  insertedIndices: changes.insertions.map { $0.0 })
    }
}

// MARK: - AuthorizingViewController

extension SearchViewController: AuthorizingViewController {
    func showAuthorizingMessage(onCancelled: @escaping () -> Void) {
        parameters.environment.navigationController?
            .showAuthorizingMessage(onCancelled: onCancelled)
    }
    func hideAuthorizingMessage() {
        parameters.environment.navigationController?
            .hideAuthorizingMessage()
    }
}

class SearchNoResultsCell: TableViewCell {
}
