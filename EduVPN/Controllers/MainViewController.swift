//
//  MainViewController.swift
//  EduVPN
//

import Foundation
import os.log
import PromiseKit

protocol MainViewControllerDelegate: AnyObject {
    func mainViewControllerAddedServersListChanged(
        _ viewController: MainViewController)
    func mainViewController(
        _ viewController: MainViewController,
        didObserveConnectionFlowStatusChange status: ConnectionViewModel.ConnectionFlowStatus,
        in connectionViewController: ConnectionViewController)
    func mainViewController(
        _ viewController: MainViewController,
        didObserveIsVPNTogglableBecame isTogglable: Bool,
        in connectionViewController: ConnectionViewController)
}

class MainViewController: ViewController {

    var environment: Environment! {
        didSet {
            viewModel = MainViewModel(
                persistenceService: environment.persistenceService,
                serverDiscoveryService: environment.serverDiscoveryService)
            viewModel.delegate = self
            environment.navigationController?.addButtonDelegate = self
            if !environment.persistenceService.hasServers {
                if Config.shared.apiDiscoveryEnabled ?? false {
                    let searchVC = environment.instantiateSearchViewController(
                        shouldIncludeOrganizations: true, shouldAutoFocusSearchField: false)
                    searchVC.delegate = self
                    environment.navigationController?.pushViewController(searchVC, animated: false)
                } else {
                    let addServerVC = environment.instantiateAddServerViewController(
                        predefinedProvider: Config.shared.predefinedProvider,
                        shouldAutoFocusURLField: true)
                    addServerVC.delegate = self
                    environment.navigationController?.pushViewController(addServerVC, animated: true)
                }
            }
            environment.connectionService.initializationDelegate = self
            environment.notificationService.delegate = self
        }
    }

    weak var delegate: MainViewControllerDelegate?

    var currentConnectionVC: ConnectionViewController? {
        if let topVC = environment.navigationController?.topViewController,
           let connectionVC = topVC as? ConnectionViewController {
            return connectionVC
        }
        return nil
    }

    private(set) var viewModel: MainViewModel!
    private var isTableViewInitialized = false
    private var isConnectionServiceInitialized = false
    // swiftlint:disable:next identifier_name
    private var shouldRenewSessionWhenConnectionServiceInitialized = false

    #if os(macOS)
    var shouldPerformActionOnSelection = true
    #endif

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

    #if os(macOS)
    override func viewDidLoad() {
        tableView.refusesFirstResponder = true
        tableView.action = #selector(onTableClicked)
        tableView.target = self
    }
    #endif

    func refresh() {
        viewModel.update()
    }

    func pushConnectionVC(connectableInstance: ConnectableInstance,
                          preConnectionState: ConnectionAttempt.PreConnectionState?,
                          continuationPolicy: ConnectionViewModel.FlowContinuationPolicy,
                          shouldRenewSessionOnRestoration: Bool = false) {
        if let currentConnectionVC = currentConnectionVC,
           currentConnectionVC.connectableInstance.isEqual(to: connectableInstance),
           preConnectionState == nil {
            currentConnectionVC.beginConnectionFlow(continuationPolicy: continuationPolicy)
        } else {
            let serverDisplayInfo = viewModel.serverDisplayInfo(for: connectableInstance)
            let authURLTemplate = viewModel.authURLTemplate(for: connectableInstance)
            let connectionVC = environment.instantiateConnectionViewController(
                connectableInstance: connectableInstance,
                serverDisplayInfo: serverDisplayInfo,
                initialConnectionFlowContinuationPolicy: continuationPolicy,
                authURLTemplate: authURLTemplate,
                restoringPreConnectionState: preConnectionState)
            connectionVC.delegate = self
            environment.navigationController?.popToRoot()
            environment.navigationController?.pushViewController(connectionVC, animated: true)
            if preConnectionState != nil && shouldRenewSessionOnRestoration {
                connectionVC.renewSession()
            }
        }
    }

    func scheduleSessionExpiryNotificationOnActiveVPN() -> Guarantee<Bool> {
        guard let currentConnectionVC = currentConnectionVC else {
            return Guarantee<Bool>.value(false)
        }
        return currentConnectionVC.scheduleSessionExpiryNotificationOnActiveVPN()
    }
}

extension MainViewController: NavigationControllerAddButtonDelegate {
    func addButtonClicked(inNavigationController controller: NavigationController) {
        showSearchVCOrAddServerVC()
    }

    func showSearchVCOrAddServerVC() {
        if Config.shared.apiDiscoveryEnabled ?? false {
            let isSecureInternetServerAdded = (environment.persistenceService.secureInternetServer != nil)
            let searchVC = environment.instantiateSearchViewController(
                shouldIncludeOrganizations: !isSecureInternetServerAdded,
                shouldAutoFocusSearchField: true)
            searchVC.delegate = self
            environment.navigationController?.pushViewController(searchVC, animated: true)
        } else {
            let addServerVC = environment.instantiateAddServerViewController(
                predefinedProvider: nil, shouldAutoFocusURLField: true)
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
        flowStatusChanged status: ConnectionViewModel.ConnectionFlowStatus) {
        delegate?.mainViewController(
            self, didObserveConnectionFlowStatusChange: status, in: controller)
    }

    func connectionViewController(
        _ controller: ConnectionViewController,
        willAttemptToConnect connectionAttempt: ConnectionAttempt?) {
        guard let connectionAttempt = connectionAttempt else {
            environment.persistenceService.removeLastConnectionAttempt()
            return
        }
        environment.persistenceService.saveLastConnectionAttempt(connectionAttempt)
    }

    func connectionViewController(
        _ controller: ConnectionViewController, isVPNTogglableBecame isTogglable: Bool) {
        delegate?.mainViewController(
            self, didObserveIsVPNTogglableBecame: isTogglable, in: controller)
    }
}

extension MainViewController: ConnectionServiceInitializationDelegate {
    func connectionService(
        _ service: ConnectionServiceProtocol,
        initializedWithState initializedState: ConnectionServiceInitializedState) {
        guard !isConnectionServiceInitialized else { return }
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

            let connectableInstance = lastConnectionAttempt.connectableInstance
            let preConnectionState = lastConnectionAttempt.preConnectionState
            if connectableInstance is ServerInstance {
                precondition(lastConnectionAttempt.preConnectionState.serverState != nil)
            } else if connectableInstance is VPNConfigInstance {
                precondition(lastConnectionAttempt.preConnectionState.vpnConfigState != nil)
            } else {
                os_log("VPN is enabled at launch, but unable to identify the server from the info in last_connection_attempt.json. Disabling VPN.",
                       log: Log.general, type: .debug)
                environment.connectionService.disableVPN()
                    .cauterize()
            }
            pushConnectionVC(
                connectableInstance: connectableInstance,
                preConnectionState: preConnectionState,
                continuationPolicy: .doNotContinue,
                shouldRenewSessionOnRestoration: shouldRenewSessionWhenConnectionServiceInitialized)

        case .vpnDisabled:
            environment.persistenceService.removeLastConnectionAttempt()
            environment.notificationService.descheduleSessionExpiryNotification()
        }
    }
}

extension MainViewController: NotificationServiceDelegate {
    func notificationServiceDidReceiveRenewSessionRequest(_ notificationService: NotificationService) {
        if isConnectionServiceInitialized {
            currentConnectionVC?.renewSession()
        } else {
            shouldRenewSessionWhenConnectionServiceInitialized = true
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
        if let connectableInstance = row.connectableInstance {
            pushConnectionVC(connectableInstance: connectableInstance,
                             preConnectionState: nil,
                             continuationPolicy: .continueWithSingleOrLastUsedProfile)
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
        case .serverByURL(server: let server, _):
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
            if Config.shared.apiDiscoveryEnabled ?? false {
                let searchVC = environment.instantiateSearchViewController(
                    shouldIncludeOrganizations: true,
                    shouldAutoFocusSearchField: false)
                searchVC.delegate = self
                environment.navigationController?.pushViewController(searchVC, animated: false)
            } else {
                let addServerVC = environment.instantiateAddServerViewController(
                    predefinedProvider: Config.shared.predefinedProvider,
                    shouldAutoFocusURLField: false)
                addServerVC.delegate = self
                environment.navigationController?.pushViewController(addServerVC, animated: true)
            }
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
            delegate?.mainViewControllerAddedServersListChanged(self)
            isTableViewInitialized = true
            return
        }
        if changes.deletedIndices.isEmpty && changes.insertions.isEmpty {
            return
        }
        delegate?.mainViewControllerAddedServersListChanged(self)
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
