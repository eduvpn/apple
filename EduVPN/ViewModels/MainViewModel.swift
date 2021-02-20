//
//  MainViewModel.swift
//  EduVPN
//
//  Created by Johan Kool on 28/05/2020.
//

import Foundation
import PromiseKit
import os.log

protocol MainViewModelDelegate: class {
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
        case serverByURL(server: SimpleServerInstance)
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
            case .instituteAccessServer(_, _, let displayName): return displayName
            case .secureInternetServer(_, _, let countryName): return countryName
            case .serverByURL(let server): return server.baseURLString.toString()
            case .openVPNConfig(let instance): return instance.name
            default: return ""
            }
        }

        var server: ServerInstance? {
            switch self {
            case .instituteAccessServer(let server, _, _): return server
            case .secureInternetServer(let server, _, _): return server
            case .serverByURL(let server): return server
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
            case .serverByURL(let server): return .serverByURLServer(server)
            case .openVPNConfig(let instance): return .vpnConfigInstance(instance)
            default: return nil
            }
        }
    }

    let persistenceService: PersistenceService
    let isDiscoveryEnabled: Bool
    var instituteAccessServersMap: [DiscoveryData.BaseURLString: DiscoveryData.InstituteAccessServer] = [:]
    var secureInternetServersMap: [DiscoveryData.BaseURLString: DiscoveryData.SecureInternetServer] = [:]

    private var rows: [Row] = []

    var isEmpty: Bool { rows.isEmpty }

    init(persistenceService: PersistenceService,
         serverDiscoveryService: ServerDiscoveryService?) {
        self.persistenceService = persistenceService

        if let serverDiscoveryService = serverDiscoveryService {
            isDiscoveryEnabled = true
            serverDiscoveryService.delegate = self
            firstly {
                serverDiscoveryService.getServers(from: .cache)
            }.catch { _ in
                // If there's no data in the cache, get it from the file
                // included in the app bundle. Then schedule a download
                // from the server.
                firstly {
                    serverDiscoveryService.getServers(from: .appBundle)
                }.then { _ in
                    serverDiscoveryService.getServers(from: .server)
                }.catch { error in
                    os_log("Error loading discovery data for main listing: %{public}@",
                           log: Log.general, type: .error,
                           error.localizedDescription)
                }
            }
        } else {
            isDiscoveryEnabled = false
            DispatchQueue.main.async { // Ensure delegate is set
                self.update()
            }
        }
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
}

extension MainViewModel {
    func update() {
        var instituteAccessRows: [Row] = []
        var secureInternetRows: [Row] = []
        var serverByURLRows: [Row] = []
        var openVPNConfigRows: [Row] = []

        for simpleServer in persistenceService.simpleServers {
            let baseURLString = simpleServer.baseURLString
            if isDiscoveryEnabled,
               let discoveredServer = instituteAccessServersMap[baseURLString] {
                let displayInfo = ServerDisplayInfo.instituteAccessServer(discoveredServer)
                let displayName = displayInfo.serverName()
                instituteAccessRows.append(.instituteAccessServer(server: simpleServer, displayInfo: displayInfo, displayName: displayName))
            } else {
                serverByURLRows.append(.serverByURL(server: simpleServer))
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
        if !serverByURLRows.isEmpty || !openVPNConfigRows.isEmpty {
            computedRows.append(.otherServerSectionHeader)
            computedRows.append(contentsOf: serverByURLRows)
            computedRows.append(contentsOf: openVPNConfigRows)
        }
        computedRows.sort()

        let diff = computedRows.rowsDifference(from: self.rows)
        self.rows = computedRows
        self.delegate?.mainViewModel(self, rowsChanged: diff)
    }

    func serverDisplayInfo(for secureInternetServer: SecureInternetServerInstance) -> ServerDisplayInfo {
        let baseURLString = secureInternetServer.apiBaseURLString
        return .secureInternetServer(secureInternetServersMap[baseURLString])
    }

    func serverDisplayInfo(for simpleServer: SimpleServerInstance) -> ServerDisplayInfo {
        let baseURLString = simpleServer.baseURLString
        if let discoveredServer = instituteAccessServersMap[baseURLString] {
            return .instituteAccessServer(discoveredServer)
        } else {
            return .serverByURLServer(simpleServer)
        }
    }

    func authURLTemplate(for server: ServerInstance) -> String? {
        guard server is SecureInternetServerInstance else { return nil }
        return secureInternetServersMap[server.authBaseURLString]?.authenticationURLTemplate
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
