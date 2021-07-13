//
//  SearchViewController.swift
//  EduVPN
//

import Foundation
import PromiseKit
import AppAuth
import os.log

protocol SearchViewControllerDelegate: AnyObject {
    func searchViewController(
        _ controller: SearchViewController,
        addedSimpleServerWithBaseURL baseURLString: DiscoveryData.BaseURLString,
        authState: AuthState)
    func searchViewController(
        _ controller: SearchViewController,
        addedSecureInternetServerWithBaseURL baseURLString: DiscoveryData.BaseURLString,
        orgId: String, authState: AuthState)
}

final class SearchViewController: ViewController, ParametrizedViewController {
    struct Parameters {
        let environment: Environment
        let shouldIncludeOrganizations: Bool
        let shouldAutoFocusSearchField: Bool
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
    #if os(macOS)
    @IBOutlet weak var searchField: SearchField!
    #elseif os(iOS)
    @IBOutlet weak var searchField: UISearchBar!
    #endif

    private var isTableViewShown: Bool = false
    private var shouldAutoFocusSearchField: Bool = false

    var isBusy: Bool = false {
        didSet { updateIsUserAllowedToGoBack() }
    }
    private(set) var hasAddedServers: Bool = false {
        didSet { updateIsUserAllowedToGoBack() }
    }

    #if os(macOS)
    var navigationController: NavigationController? { parameters.environment.navigationController }
    var shouldPerformActionOnSelection = true
    #endif

    #if os(iOS)
    var contactingServerAlert: UIAlertController?
    #endif

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
        self.shouldAutoFocusSearchField = parameters.shouldAutoFocusSearchField
    }

    override func viewDidLoad() {
        title = NSLocalizedString("Add Server", comment: "Search / Add server screen title")
        spinner.setLayerOpacity(0)
        tableContainerView.setLayerOpacity(0)

        let persistenceService = parameters.environment.persistenceService
        persistenceService.hasServersDelegate = self
        hasAddedServers = persistenceService.hasServers

        if shouldAutoFocusSearchField {
            showTableView(animated: false)
        }

        #if os(macOS)
        tableView.refusesFirstResponder = true
        tableView.action = #selector(onTableClicked)
        tableView.target = self
        #endif
    }

    #if os(macOS)
    override func viewDidAppear() {
        if shouldAutoFocusSearchField {
            self.view.window?.makeFirstResponder(searchField)
        }
        shouldAutoFocusSearchField = false
        super.viewDidAppear()
    }
    #endif

    #if os(iOS)
    override func viewDidAppear(_ animated: Bool) {
        if shouldAutoFocusSearchField {
            searchField.becomeFirstResponder()
        }
        shouldAutoFocusSearchField = false
        super.viewDidAppear(animated)
    }
    #endif

    func showTableView(animated: Bool) {
        if isTableViewShown {
            return
        }
        isTableViewShown = true
        for view in [topSpacerView, topImageView] {
            view?.removeFromSuperview()
        }
        if animated {
            performWithAnimation(seconds: 0.5) {
                self.spinner.setLayerOpacity(1)
                self.tableContainerView.setLayerOpacity(1)
                self.stackView.layoutIfNeeded()
            }
        } else {
            self.spinner.setLayerOpacity(1)
            self.tableContainerView.setLayerOpacity(1)
            self.stackView.layoutIfNeeded()
        }
        spinner.startAnimation(self)
        firstly {
            self.viewModel.load(from: .cache)
        }.recover { _ in
            // If there's no data in the cache, load from the files
            // included in the app bundle
            self.viewModel.load(from: .appBundle)
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

    func updateIsUserAllowedToGoBack() {
        parameters.environment.navigationController?.isUserAllowedToGoBack = hasAddedServers && !isBusy
    }
}

// MARK: - Search field

extension SearchViewController {
    func searchFieldGotFocus() {
        showTableView(animated: true)
    }

    func searchFieldTextChanged(text: String) {
        viewModel.setSearchQuery(text)
    }
}

// MARK: - Table view delegate and data source

extension SearchViewController {
    func hasResults() -> Bool {
        return viewModel?.hasResults() ?? false
    }

    func numberOfRows() -> Int {
        return viewModel?.numberOfRows() ?? 0
    }

    func cellForRow(at index: Int, tableView: TableView) -> TableViewCell {
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
                serverAuthService.startAuth(baseURLString: baseURLString, from: self,
                                            wayfSkippingInfo: viewModel.wayfSkippingInfo(for: row))
            }.map { authState in
                switch row {
                case .instituteAccessServer, .serverByURL:
                    delegate?.searchViewController(
                        self, addedSimpleServerWithBaseURL: baseURLString,
                        authState: authState)
                case .secureInternetOrg(let organization):
                    delegate?.searchViewController(
                        self, addedSecureInternetServerWithBaseURL: baseURLString,
                        orgId: organization.orgId, authState: authState)
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
    func searchViewModel(
        _ model: SearchViewModel,
        rowsChanged changes: RowsDifference<SearchViewModel.Row>) {
        tableView?.performUpdates(deletedIndices: changes.deletedIndices,
                                  insertedIndices: changes.insertions.map { $0.0 })
    }
}

// MARK: - PersistenceService hasServers delegate

extension SearchViewController: PersistenceServiceHasServersDelegate {
    func persistenceService(_ persistenceService: PersistenceService, hasServersChangedTo hasServers: Bool) {
        hasAddedServers = hasServers
    }
}

class SearchNoResultsCell: TableViewCell {
}
