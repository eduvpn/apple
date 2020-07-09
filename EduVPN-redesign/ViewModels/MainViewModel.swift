//
//  MainViewModel.swift
//  EduVPN
//
//  Created by Johan Kool on 28/05/2020.
//

import Foundation
import PromiseKit

protocol MainViewModelDelegate: class {
    func rowsChanged(changes: RowsDifference<MainViewModel.Row>)
}

class MainViewModel {
    weak var delegate: MainViewModelDelegate?

    enum Row: ViewModelRow {
        case instituteAccessServerSectionHeader
        case instituteAccessServer(server: SimpleServerInstance, displayName: String)
        case secureInternetServerSectionHeader
        case secureInternetServer(server: SecureInternetServerInstance,
            countryCode: String, countryName: String)
        case serverByURLSectionHeader
        case serverByURL(server: SimpleServerInstance)

        var rowKind: ViewModelRowKind {
            switch self {
            case .instituteAccessServerSectionHeader: return .instituteAccessServerSectionHeaderKind
            case .instituteAccessServer: return .instituteAccessServerKind
            case .secureInternetServerSectionHeader: return .secureInternetServerSectionHeaderKind
            case .secureInternetServer: return .secureInternetServerKind
            case .serverByURLSectionHeader: return .serverByURLSectionHeaderKind
            case .serverByURL: return .serverByURLKind
            }
        }

        var displayText: String {
            switch self {
            case .instituteAccessServer(_, let displayName): return displayName
            case .secureInternetServer(_, _, let countryName): return countryName
            case .serverByURL(let server): return server.baseURL.absoluteString
            default: return ""
            }
        }
    }

    let persistenceService: PersistenceService
    var instituteAccessServersMap: [DiscoveryData.BaseURLString: DiscoveryData.InstituteAccessServer] = [:]
    var secureInternetServersMap: [DiscoveryData.BaseURLString: DiscoveryData.SecureInternetServer] = [:]

    private var rows: [Row] = []

    var isEmpty: Bool { rows.isEmpty }

    init(persistenceService: PersistenceService,
         serverDiscoveryService: ServerDiscoveryService?) {
        self.persistenceService = persistenceService

        if let serverDiscoveryService = serverDiscoveryService {
            serverDiscoveryService.delegate = self
            serverDiscoveryService.getServers(from: .cache)
                .cauterize()
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

        for simpleServer in persistenceService.simpleServers {
            let baseURLString = simpleServer.baseURL.absoluteString
            if let discoveredServer = instituteAccessServersMap[baseURLString] {
                let displayName = discoveredServer.displayName.string(for: Locale.current)
                instituteAccessRows.append(.instituteAccessServer(server: simpleServer, displayName: displayName))
            } else {
                serverByURLRows.append(.serverByURL(server: simpleServer))
            }
        }

        if let secureInternetServer = persistenceService.secureInternetServer {
            let baseURLString = secureInternetServer.apiBaseURL.absoluteString
            if let discoveredServer = secureInternetServersMap[baseURLString] {
                let countryCode = discoveredServer.countryCode
                let countryName = Locale.current.localizedString(forRegionCode: countryCode) ?? "Unknown country"
                secureInternetRows.append(.secureInternetServer(server: secureInternetServer,
                                                                countryCode: countryCode,
                                                                countryName: countryName))
            } else {
                secureInternetRows.append(.secureInternetServer(server: secureInternetServer,
                                                                countryCode: "",
                                                                countryName: "Unknown country"))
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
        if !serverByURLRows.isEmpty {
            computedRows.append(.serverByURLSectionHeader)
            computedRows.append(contentsOf: serverByURLRows)
        }

        assert(computedRows == computedRows.sorted(), "computedRows is not ordered correctly")
        let diff = computedRows.rowsDifference(from: self.rows)
        self.rows = computedRows
        self.delegate?.rowsChanged(changes: diff)
    }
}

extension MainViewModel: ServerDiscoveryServiceServersDelegate {
    func serversChanged(_ servers: DiscoveryData.Servers) {
        self.instituteAccessServersMap = Dictionary(grouping: servers.instituteAccessServers, by: { $0.baseURLString })
            .mapValues { $0.first! } // swiftlint:disable:this force_unwrapping
        self.secureInternetServersMap = servers.secureInternetServersMap
        self.update()
    }
}
