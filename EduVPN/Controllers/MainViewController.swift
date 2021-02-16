//
//  MainViewController.swift
//  EduVPN
//

import Foundation
import os.log

class MainViewController: ViewController {

    var environment: Environment! {
        didSet {
            viewModel = MainViewModel(
                persistenceService: environment.persistenceService,
                serverDiscoveryService: environment.serverDiscoveryService)
            viewModel.delegate = self
            environment.navigationController?.addButtonDelegate = self
            if !environment.persistenceService.hasServers {
                let searchVC = environment.instantiateSearchViewController(
                    shouldIncludeOrganizations: true, shouldAutoFocusSearchField: false)
                searchVC.delegate = self
                environment.navigationController?.pushViewController(searchVC, animated: false)
            }
            environment.connectionService.initializationDelegate = self
        }
    }

    private var viewModel: MainViewModel!
    private var isTableViewInitialized = false
    private var isConnectionServiceInitialized = false

    @IBOutlet weak var tableView: TableView!

    #if os(iOS)
    private var isViewVisible = false
    private var hasPendingUpdates = false

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        isViewVisible = true
        if hasPendingUpdates {
            tableView.reloadData()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        isViewVisible = false
    }
    #endif

    func refresh() {
        viewModel.update()
    }
}

extension MainViewController: NavigationControllerAddButtonDelegate {
    func addButtonClicked(inNavigationController controller: NavigationController) {
        if Config.shared.apiDiscoveryEnabled ?? false {
            let isSecureInternetServerAdded = (environment.persistenceService.secureInternetServer != nil)
            let searchVC = environment.instantiateSearchViewController(
                shouldIncludeOrganizations: !isSecureInternetServerAdded,
                shouldAutoFocusSearchField: true)
            searchVC.delegate = self
            environment.navigationController?.pushViewController(searchVC, animated: true)
        } else {
            let addServerVC = environment.instantiateAddServerViewController(preDefinedProvider: nil)
            addServerVC.delegate = self
            environment.navigationController?.pushViewController(addServerVC, animated: true)
        }
    }
}

extension MainViewController: SearchViewControllerDelegate {
    func searchViewController(
        _ controller: SearchViewController,
        addedSimpleServerWithBaseURL baseURLString: DiscoveryData.BaseURLString,
        authState: AuthState) {
        let storagePath = UUID().uuidString
        let dataStore = PersistenceService.DataStore(path: storagePath)
        dataStore.authState = authState
        let server = SimpleServerInstance(baseURLString: baseURLString, localStoragePath: storagePath)
        environment.persistenceService.addSimpleServer(server)
        viewModel.update()
        environment.navigationController?.popViewController(animated: true)
    }

    func searchViewController(
        _ controller: SearchViewController,
        addedSecureInternetServerWithBaseURL baseURLString: DiscoveryData.BaseURLString,
        orgId: String, authState: AuthState) {
        let storagePath = UUID().uuidString
        let dataStore = PersistenceService.DataStore(path: storagePath)
        dataStore.authState = authState
        let server = SecureInternetServerInstance(
            apiBaseURLString: baseURLString, authBaseURLString: baseURLString,
            orgId: orgId, localStoragePath: storagePath)
        environment.persistenceService.setSecureInternetServer(server)
        viewModel.update()
        environment.navigationController?.popViewController(animated: true)
    }
}

extension MainViewController: AddServerViewControllerDelegate {
    func addServerViewController(
        _ controller: AddServerViewController,
        addedSimpleServerWithBaseURL baseURLString: DiscoveryData.BaseURLString,
        authState: AuthState) {
        let storagePath = UUID().uuidString
        let dataStore = PersistenceService.DataStore(path: storagePath)
        dataStore.authState = authState
        let server = SimpleServerInstance(baseURLString: baseURLString, localStoragePath: storagePath)
        environment.persistenceService.addSimpleServer(server)
        viewModel.update()
        environment.navigationController?.popViewController(animated: true)
    }
}

extension MainViewController: ConnectionViewControllerDelegate {
    func connectionViewController(
        _ controller: ConnectionViewController,
        willAttemptToConnect connectionAttempt: ConnectionAttempt?) {
        guard let connectionAttempt = connectionAttempt else {
            environment.persistenceService.removeLastConnectionAttempt()
            return
        }
        environment.persistenceService.saveLastConnectionAttempt(connectionAttempt)
    }
}

extension MainViewController: ConnectionServiceInitializationDelegate {
    func connectionService( // swiftlint:disable:this function_body_length
        _ service: ConnectionServiceProtocol,
        initializedWithState initializedState: ConnectionServiceInitializedState) {
        isConnectionServiceInitialized = true
        switch initializedState {
        case .vpnEnabled(let connectionAttemptId):
            // If some VPN is enabled at launch, we should create the appropriate
            // connectionVC and push that
            guard let connectionAttemptId = connectionAttemptId,
                let lastConnectionAttempt = environment.persistenceService.loadLastConnectionAttempt(),
                connectionAttemptId == lastConnectionAttempt.attemptId else {
                    os_log("VPN is enabled at launch, but there's no matching entry in last_connection_attempt.json. Disabling VPN.",
                           log: Log.general, type: .debug)
                    environment.connectionService.disableVPN()
                        .cauterize()
                    return
            }

            let connectionVC: ConnectionViewController? = {
                let connectableInstance = lastConnectionAttempt.connectableInstance
                if let simpleServer = connectableInstance as? SimpleServerInstance {
                    precondition(lastConnectionAttempt.preConnectionState.serverState != nil)
                    return environment.instantiateConnectionViewController(
                        connectableInstance: simpleServer,
                        serverDisplayInfo: viewModel.serverDisplayInfo(for: simpleServer),
                        authURLTemplate: nil,
                        restoringPreConnectionState: lastConnectionAttempt.preConnectionState)
                } else if let secureInternetServer = connectableInstance as? SecureInternetServerInstance {
                    precondition(lastConnectionAttempt.preConnectionState.serverState != nil)
                    return environment.instantiateConnectionViewController(
                        connectableInstance: secureInternetServer,
                        serverDisplayInfo: viewModel.serverDisplayInfo(for: secureInternetServer),
                        authURLTemplate: viewModel.authURLTemplate(for: secureInternetServer),
                        restoringPreConnectionState: lastConnectionAttempt.preConnectionState)
                } else if let openVPNConfigInstance = connectableInstance as? OpenVPNConfigInstance {
                    precondition(lastConnectionAttempt.preConnectionState.vpnConfigState != nil)
                    return environment.instantiateConnectionViewController(
                        connectableInstance: openVPNConfigInstance,
                        serverDisplayInfo: .vpnConfigInstance(openVPNConfigInstance),
                        restoringPreConnectionState: lastConnectionAttempt.preConnectionState)
                }
                return nil
            }()
            if let connectionVC = connectionVC {
                environment.navigationController?.popToRoot()
                environment.navigationController?.pushViewController(connectionVC, animated: true)
            } else {
                os_log("VPN is enabled at launch, but unable to identify the server from the info in last_connection_attempt.json. Disabling VPN.",
                       log: Log.general, type: .debug)
                environment.connectionService.disableVPN()
                    .cauterize()
            }
        case .vpnDisabled:
            environment.persistenceService.removeLastConnectionAttempt()
        }
    }
}

extension MainViewController {
    func numberOfRows() -> Int {
        return viewModel?.numberOfRows() ?? 0
    }

    func cellForRow(at index: Int, tableView: TableView) -> TableViewCell {
        let row = viewModel.row(at: index)
        if row.rowKind.isSectionHeader {
            if row.rowKind == .secureInternetServerSectionHeaderKind {
                let cell = tableView.dequeue(MainSecureInternetSectionHeaderCell.self,
                                             identifier: "MainSecureInternetSectionHeaderCell",
                                             indexPath: IndexPath(item: index, section: 0))
                let selectedBaseURLString = environment.persistenceService.secureInternetServer?.apiBaseURLString
                    ?? DiscoveryData.BaseURLString(urlString: "")
                cell.configureMainSecureInternetSectionHeader(
                    environment: environment,
                    containingViewController: self,
                    serversMap: viewModel.secureInternetServersMap,
                    selectedBaseURLString: selectedBaseURLString,
                    onLocationChanged: { baseURLString in
                        self.environment.persistenceService.setSecureInternetServerAPIBaseURLString(baseURLString)
                        self.viewModel.update()
                        self.reloadSecureInternetRows()
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
        guard isConnectionServiceInitialized else {
            // Don't show the connection screen until the connection service
            // is intialized
            return
        }

        let row = viewModel.row(at: index)
        if let serverDisplayInfo = row.serverDisplayInfo {
            if let server = row.server {
                let connectionVC = environment.instantiateConnectionViewController(
                    connectableInstance: server, serverDisplayInfo: serverDisplayInfo,
                    authURLTemplate: viewModel.authURLTemplate(for: server))
                connectionVC.delegate = self
                environment.navigationController?.pushViewController(connectionVC, animated: true)
            } else if let vpnConfig = row.vpnConfig {
                let connectionVC = environment.instantiateConnectionViewController(
                    connectableInstance: vpnConfig, serverDisplayInfo: serverDisplayInfo)
                connectionVC.delegate = self
                environment.navigationController?.pushViewController(connectionVC, animated: true)
            }
        }
    }

    func canDeleteRow(at index: Int) -> Bool {
        return viewModel.row(at: index).rowKind.isServerRow
    }

    func displayText(at index: Int) -> String {
        return viewModel.row(at: index).displayText
    }

    func deleteRow(at index: Int) {
        guard index < viewModel.numberOfRows() else { return }
        let persistenceService = environment.persistenceService
        switch viewModel.row(at: index) {
        case .secureInternetServer:
            persistenceService.removeSecureInternetServer()
        case .instituteAccessServer(server: let server, _, _):
            persistenceService.removeSimpleServer(server)
        case .serverByURL(server: let server):
            persistenceService.removeSimpleServer(server)
        case .openVPNConfig(instance: let instance):
            persistenceService.removeOpenVPNConfiguration(instance)
        case .instituteAccessServerSectionHeader,
             .secureInternetServerSectionHeader,
             .otherServerSectionHeader:
            break
        }
        viewModel.update()
        if !environment.persistenceService.hasServers {
            let searchVC = environment.instantiateSearchViewController(
                shouldIncludeOrganizations: true,
                shouldAutoFocusSearchField: false)
            searchVC.delegate = self
            environment.navigationController?.pushViewController(searchVC, animated: true)
        }

    }
}

extension MainViewController: MainViewModelDelegate {
    func mainViewModel(
        _ model: MainViewModel,
        rowsChanged changes: RowsDifference<MainViewModel.Row>) {
        guard let tableView = tableView else { return }
        guard isTableViewInitialized else {
            // The first time, we reload to avoid drawing errors
            tableView.reloadData()
            isTableViewInitialized = true
            return
        }
        if changes.deletedIndices.isEmpty && changes.insertions.isEmpty {
            return
        }
        #if os(iOS)
        guard isViewVisible else {
            hasPendingUpdates = true
            return
        }
        #endif
        tableView.performUpdates(deletedIndices: changes.deletedIndices,
                                 insertedIndices: changes.insertions.map { $0.0 })
    }
}

extension MainViewController {
    func reloadSecureInternetRows() {
        guard let tableView = tableView else { return }
        let indices = self.viewModel.secureInternetRowIndices()
        tableView.reloadRows(indices: indices)
    }
}
