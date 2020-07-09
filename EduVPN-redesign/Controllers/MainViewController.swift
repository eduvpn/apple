//
//  MainViewController.swift
//  EduVPN
//

import Foundation

class MainViewController: ViewController {

    var environment: Environment! {
        didSet {
            viewModel = MainViewModel(
                persistenceService: environment.persistenceService,
                serverDiscoveryService: environment.serverDiscoveryService)
            viewModel.delegate = self
            environment.navigationController?.delegate = self
            if !environment.persistenceService.hasServers {
                let searchVC = environment.instantiateSearchViewController(shouldIncludeOrganizations: true)
                searchVC.delegate = self
                environment.navigationController?.pushViewController(searchVC, animated: false)
                environment.navigationController?.isUserAllowedToGoBack = false
            }
        }
    }

    private var viewModel: MainViewModel!
    private var isTableViewInitialized = false

    @IBOutlet weak var tableView: TableView!
}

extension MainViewController: NavigationControllerDelegate {
    func addServerButtonClicked() {
        let isSecureInternetServerAdded = (environment.persistenceService.secureInternetServer != nil)
        let searchVC = environment.instantiateSearchViewController(shouldIncludeOrganizations: !isSecureInternetServerAdded)
        searchVC.delegate = self
        environment.navigationController?.pushViewController(searchVC, animated: true)
    }
}

extension MainViewController: SearchViewControllerDelegate {
    func searchViewControllerAddedSimpleServer(baseURL: URL, authState: AuthState) {
        let storagePath = UUID().uuidString
        let dataStore = PersistenceService.ServerDataStore(path: storagePath)
        dataStore.authState = authState
        let server = SimpleServerInstance(baseURL: baseURL, localStoragePath: storagePath)
        environment.persistenceService.addSimpleServer(server)
        viewModel.update()
        environment.navigationController?.popViewController(animated: true)
    }

    func searchViewControllerAddedSecureInternetServer(baseURL: URL, orgId: String, authState: AuthState) {
        let storagePath = UUID().uuidString
        let dataStore = PersistenceService.ServerDataStore(path: storagePath)
        dataStore.authState = authState
        let server = SecureInternetServerInstance(
            apiBaseURL: baseURL, authBaseURL: baseURL,
            orgId: orgId, localStoragePath: storagePath)
        environment.persistenceService.setSecureInternetServer(server)
        viewModel.update()
        environment.navigationController?.popViewController(animated: true)
    }
}

extension MainViewController {
    func numberOfRows() -> Int {
        return viewModel?.numberOfRows() ?? 0
    }

    func cellForRow(at index: Int, tableView: TableView) -> NSView? {
        let row = viewModel.row(at: index)
        if row.rowKind.isSectionHeader {
            if row.rowKind == .secureInternetServerSectionHeaderKind {
                let cell = tableView.dequeue(MainSecureInternetSectionHeaderCell.self,
                                             identifier: "MainSecureInternetSectionHeaderCell",
                                             indexPath: IndexPath(item: index, section: 0))
                let selectedBaseURLString = environment.persistenceService.secureInternetServer?.apiBaseURL.absoluteString ?? ""
                cell.configureMainSecureInternetSectionHeader(
                    serversMap: viewModel.secureInternetServersMap,
                    selectedBaseURLString: selectedBaseURLString,
                    onLocationChanged: { baseURLString in
                        if let url = URL(string: baseURLString) {
                            self.environment.persistenceService.setSecureInternetServerAPIBaseURL(url)
                            self.viewModel.update()
                            self.reloadSecureInternetRows()
                        }
                    })
                return cell
            } else {
                let cell = tableView.dequeue(SectionHeaderCell.self,
                                             identifier: "MainSectionHeaderCell",
                                             indexPath: IndexPath(item: index, section: 0))
                cell.configure(as: row.rowKind, isAdding: false)
                return cell
            }
        } else if row.rowKind == .secureInternetServerKind {
            let cell = tableView.dequeue(RowCell.self,
                                         identifier: "SecureInternetServerRowCell",
                                         indexPath: IndexPath(item: index, section: 0))
            cell.configure(with: row)
            return cell
        } else {
            let cell = tableView.dequeue(RowCell.self,
                                         identifier: "SimpleServerRowCell",
                                         indexPath: IndexPath(item: index, section: 0))
            cell.configure(with: row)
            return cell
        }
    }

    func canSelectRow(at index: Int) -> Bool {
        return viewModel.row(at: index).rowKind.isServerRow
    }

    func didSelectRow(at index: Int) {
        print("Selected: \(viewModel.row(at: index))")
    }

    func canDeleteRow(at index: Int) -> Bool {
        return viewModel.row(at: index).rowKind.isServerRow
    }

    func deleteRow(at index: Int) {
        guard index < viewModel.numberOfRows() else { return }
        let persistenceService = environment.persistenceService
        switch viewModel.row(at: index) {
        case .secureInternetServer:
            persistenceService.removeSecureInternetServer()
        case .instituteAccessServer(server: let server, displayName: _):
            persistenceService.removeSimpleServer(server)
        case .serverByURL(server: let server):
            persistenceService.removeSimpleServer(server)
        case .instituteAccessServerSectionHeader,
             .secureInternetServerSectionHeader,
             .serverByURLSectionHeader:
            break
        }
        viewModel.update()
        if !environment.persistenceService.hasServers {
            let searchVC = environment.instantiateSearchViewController(shouldIncludeOrganizations: true)
            searchVC.delegate = self
            environment.navigationController?.pushViewController(searchVC, animated: true)
            environment.navigationController?.isUserAllowedToGoBack = false
        }

    }
}

extension MainViewController: MainViewModelDelegate {
    func rowsChanged(changes: RowsDifference<MainViewModel.Row>) {
        guard let tableView = tableView else { return }
        guard isTableViewInitialized else {
            // The first time, we reload to avoid drawing errors
            tableView.reloadData()
            isTableViewInitialized = true
            return
        }
        tableView.performUpdates(deletedIndices: changes.deletedIndices,
                                 insertedIndices: changes.insertions.map { $0.0 })
    }
}

extension MainViewController {
    func reloadSecureInternetRows() {
        guard let tableView = tableView else { return }
        let indices = self.viewModel.secureInternetRowIndices()
        tableView.reloadData(forRowIndexes: IndexSet(indices), columnIndexes: IndexSet([0]))
    }
}
