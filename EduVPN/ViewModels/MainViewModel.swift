//
//  MainViewModel.swift
//  EduVPN
//
//  Created by Johan Kool on 28/05/2020.
//

import Foundation
import PromiseKit
import os.log

protocol MainViewModelDelegate: AnyObject {
    func mainViewModel(_ model: MainViewModel, rowsChanged changes: RowsDifference<MainViewModel.Row>)
}

class MainViewModel {
    weak var delegate: MainViewModelDelegate?

    enum Row: ViewModelRow {
        // displayName / countryName can be derived from displayInfo. But
        // they are pre-computed and stored so that we don't have to compute it
        // every time the table view cell is dequeued.
        case instituteAccessServerSectionHeader
        case instituteAccessServer(
            server: SimpleServerInstance,
            displayInfo: ServerDisplayInfo,
            displayName: String)
        case secureInternetServerSectionHeader
        case secureInternetServer(
            server: SecureInternetServerInstance,
            displayInfo: ServerDisplayInfo,
            countryName: String)
        case otherServerSectionHeader
        case serverByURL(server: SimpleServerInstance, displayName: String?)
        case openVPNConfig(instance: OpenVPNConfigInstance)

        var rowKind: ViewModelRowKind {
            switch self {
            case .instituteAccessServerSectionHeader: return .instituteAccessServerSectionHeaderKind
            case .instituteAccessServer: return .instituteAccessServerKind
            case .secureInternetServerSectionHeader: return .secureInternetServerSectionHeaderKind
            case .secureInternetServer: return .secureInternetServerKind
            case .otherServerSectionHeader: return .otherServerSectionHeaderKind
            case .serverByURL: return .serverByURLKind
            case .openVPNConfig: return .openVPNConfigKind
            }
        }

        var displayText: String {
            switch self {
            case .instituteAccessServerSectionHeader:
                return NSLocalizedString("Institute Access", comment: "list section header")
            case .secureInternetServerSectionHeader:
                return NSLocalizedString("Secure Internet", comment: "list section header")
            case .otherServerSectionHeader:
                return NSLocalizedString("Other servers", comment: "list section header")
            case .instituteAccessServer(_, _, let displayName): return displayName
            case .secureInternetServer(_, _, let countryName): return countryName
            case .serverByURL(let server, let displayName):
                return displayName ?? server.baseURLString.toString()
            case .openVPNConfig(let instance): return instance.name
            }
        }

        var connectableInstance: ConnectableInstance? {
            switch self {
            case .instituteAccessServer(let server, _, _): return server
            case .secureInternetServer(let server, _, _): return server
            case .serverByURL(let server, _): return server
            case .openVPNConfig(let instance): return instance
            default: return nil
            }
        }

        var server: ServerInstance? {
            switch self {
            case .instituteAccessServer(let server, _, _): return server
            case .secureInternetServer(let server, _, _): return server
            case .serverByURL(let server, _): return server
            default: return nil
            }
        }

        var vpnConfig: VPNConfigInstance? {
            switch self {
            case .openVPNConfig(let instance): return instance
            default: return nil
            }
        }

        var serverDisplayInfo: ServerDisplayInfo? {
            switch self {
            case .instituteAccessServer(_, let displayInfo, _): return displayInfo
            case .secureInternetServer(_, let displayInfo, _): return displayInfo
            case .serverByURL(let server, _): return .serverByURLServer(server)
            case .openVPNConfig(let instance): return .vpnConfigInstance(instance)
            default: return nil
            }
        }
    }

    let persistenceService: PersistenceService
    let serverDiscoveryService: ServerDiscoveryService?
    let isDiscoveryEnabled: Bool
    var instituteAccessServersMap: [DiscoveryData.BaseURLString: DiscoveryData.InstituteAccessServer] = [:]
    var secureInternetServersMap: [DiscoveryData.BaseURLString: DiscoveryData.SecureInternetServer] = [:]

    private(set) var rows: [Row] = []

    var isEmpty: Bool { rows.isEmpty }

    private var timer: Timer? {
        didSet(oldValue) {
            oldValue?.invalidate()
        }
    }

    deinit {
        self.timer = nil // invalidate
    }

    init(persistenceService: PersistenceService,
         serverDiscoveryService: ServerDiscoveryService?) {
        self.persistenceService = persistenceService
        self.serverDiscoveryService = serverDiscoveryService

        if let serverDiscoveryService = serverDiscoveryService {
            isDiscoveryEnabled = true
            serverDiscoveryService.delegate = self
            // If we have a cached version, use that. If not, use
            // the file included in the app bundle.
            // Then, schedule a download from the server.
            firstly {
                serverDiscoveryService.getServers(from: .cache)
                    .recover { _ in
                        serverDiscoveryService.getServers(from: .appBundle)
                    }
            }.then { _ in
                serverDiscoveryService.getServers(from: .server)
            }.catch { error in
                os_log("Error loading discovery data for main listing: %{public}@",
                       log: Log.general, type: .error,
                       error.localizedDescription)
            }
        } else {
            isDiscoveryEnabled = false
            DispatchQueue.main.async { // Ensure delegate is set
                self.update()
            }
        }
        periodicallyUpdateServerListFromServer()
    }

    func updateServerListFromServer() {
        if let serverDiscoveryService = serverDiscoveryService {
            serverDiscoveryService.getServers(from: .server)
                .cauterize()
        }
    }

    func periodicallyUpdateServerListFromServer() {
        let timer = Timer(timeInterval: 60 * 60 /*1 hour in seconds*/, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if let serverDiscoveryService = self.serverDiscoveryService {
                serverDiscoveryService.getServers(from: .server)
                    .cauterize()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func numberOfRows() -> Int {
        return rows.count
    }

    func row(at index: Int) -> Row {
        return rows[index]
    }

    func secureInternetRowIndices() -> [Int] {
        if let sectionHeaderIndex = rows.firstIndex(of: .secureInternetServerSectionHeader) {
            return [sectionHeaderIndex, sectionHeaderIndex + 1]
        }
        return []
    }

    func secureInternetHeaderRowIndex() -> Int? {
        return rows.firstIndex(of: .secureInternetServerSectionHeader)
    }
}

extension MainViewModel {
    func update() {
        var instituteAccessRows: [Row] = []
        var secureInternetRows: [Row] = []
        var namedServerByURLRows: [Row] = []
        var unnamedServerByURLRows: [Row] = []
        var openVPNConfigRows: [Row] = []

        for simpleServer in persistenceService.simpleServers {
            let baseURLString = simpleServer.baseURLString
            if isDiscoveryEnabled,
               let discoveredServer = instituteAccessServersMap[baseURLString] {
                let displayInfo = ServerDisplayInfo.instituteAccessServer(discoveredServer)
                let displayName = displayInfo.serverName()
                instituteAccessRows.append(.instituteAccessServer(server: simpleServer, displayInfo: displayInfo, displayName: displayName))
            } else if let predefinedProvider = Config.shared.predefinedProvider,
                      predefinedProvider.baseURLString == baseURLString {
                let name = predefinedProvider.displayName.stringForCurrentLanguage()
                namedServerByURLRows.append(.serverByURL(server: simpleServer, displayName: name))
            } else {
                unnamedServerByURLRows.append(.serverByURL(server: simpleServer, displayName: nil))
            }
        }

        if let secureInternetServer = persistenceService.secureInternetServer {
            let baseURLString = secureInternetServer.apiBaseURLString
            let displayInfo = ServerDisplayInfo.secureInternetServer(secureInternetServersMap[baseURLString])
            let countryName = displayInfo.serverName()
            secureInternetRows.append(.secureInternetServer(server: secureInternetServer,
                                                            displayInfo: displayInfo,
                                                            countryName: countryName))
        }

        if let openVPNConfigs = persistenceService.openVPNConfigs {
            for openVPNConfig in openVPNConfigs {
                openVPNConfigRows.append(.openVPNConfig(instance: openVPNConfig))
            }
        }

        var computedRows: [Row] = []
        if !instituteAccessRows.isEmpty {
            computedRows.append(.instituteAccessServerSectionHeader)
            computedRows.append(contentsOf: instituteAccessRows)
        }
        if !secureInternetRows.isEmpty {
            computedRows.append(.secureInternetServerSectionHeader)
            computedRows.append(contentsOf: secureInternetRows)
        }
        if !namedServerByURLRows.isEmpty || !unnamedServerByURLRows.isEmpty || !openVPNConfigRows.isEmpty {
            if !instituteAccessRows.isEmpty || !secureInternetRows.isEmpty {
                computedRows.append(.otherServerSectionHeader)
            }
            computedRows.append(contentsOf: namedServerByURLRows)
            computedRows.append(contentsOf: unnamedServerByURLRows)
            computedRows.append(contentsOf: openVPNConfigRows)
        }
        computedRows.sort()

        let diff = computedRows.rowsDifference(from: self.rows)
        self.rows = computedRows
        self.delegate?.mainViewModel(self, rowsChanged: diff)
    }

    func serverDisplayInfo(for connectableInstance: ConnectableInstance) -> ServerDisplayInfo {
        if let secureInternetServer = connectableInstance as? SecureInternetServerInstance {
            let baseURLString = secureInternetServer.apiBaseURLString
            return .secureInternetServer(secureInternetServersMap[baseURLString])
        } else if let simpleServer = connectableInstance as? SimpleServerInstance {
            let baseURLString = simpleServer.baseURLString
            if let discoveredServer = instituteAccessServersMap[baseURLString] {
                return .instituteAccessServer(discoveredServer)
            } else {
                return .serverByURLServer(simpleServer)
            }
        } else if let vpnConfigInstance = connectableInstance as? VPNConfigInstance {
            return .vpnConfigInstance(vpnConfigInstance)
        } else {
            fatalError("Unknown connectable instance type")
        }
    }

    func authURLTemplate(for server: ConnectableInstance) -> String? {
        guard let secureInternetServer = server as? SecureInternetServerInstance else {
            return nil
        }
        return secureInternetServersMap[secureInternetServer.authBaseURLString]?.authenticationURLTemplate
    }
}

extension MainViewModel: ServerDiscoveryServiceServersDelegate {
    func serverDiscoveryService(_ service: ServerDiscoveryService,
                                serversChanged servers: DiscoveryData.Servers) {
        self.instituteAccessServersMap = Dictionary(grouping: servers.instituteAccessServers, by: { $0.baseURLString })
            .mapValues { $0.first! } // swiftlint:disable:this force_unwrapping
        self.secureInternetServersMap = servers.secureInternetServersMap
        self.update()
    }
}
