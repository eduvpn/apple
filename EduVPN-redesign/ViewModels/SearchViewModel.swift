//
//  SearchViewModel.swift
//  EduVPN
//
//  Created by Johan Kool on 28/05/2020.
//

import Foundation
import PromiseKit

protocol SearchViewModelDelegate: class {
    func rowsChanged(changes: RowsDifference<SearchViewModel.Row>)
}

enum SearchViewModelError: Error {
    case cannotLoadWhenPreviousLoadIsInProgress
}

class SearchViewModel {
    weak var delegate: SearchViewModelDelegate?

    enum Row: ViewModelRow {
        case addingServerByURLSectionHeader
        case addingServerByURL(String)
        case instituteAccessServerSectionHeader
        case instituteAccessServer(LocalizedInstituteAccessServer)
        case secureInternetOrgSectionHeader
        case secureInternetOrg(LocalizedOrganization)

        var rowKind: ViewModelRowKind {
            switch self {
            case .addingServerByURLSectionHeader: return .addingServerByURLSectionHeaderKind
            case .addingServerByURL: return .addingServerByURLKind
            case .instituteAccessServerSectionHeader: return .instituteAccessServerSectionHeaderKind
            case .instituteAccessServer: return .instituteAccessServerKind
            case .secureInternetOrgSectionHeader: return .secureInternetOrgSectionHeaderKind
            case .secureInternetOrg: return .secureInternetOrgKind
            }
        }

        var displayText: String {
            switch self {
            case .instituteAccessServer(let server): return server.displayName
            case .secureInternetOrg(let organization): return organization.displayName
            case .addingServerByURL(let urlString): return urlString
            default: return ""
            }
        }
    }

    enum Scope {
        case serverByURLOnly
        case instituteAccessOrServerByURL
        case all

        var includesInstituteAccessServers: Bool {
            self == .instituteAccessOrServerByURL || self == .all
        }

        var includesOrganizations: Bool {
            self == .all
        }
    }

    struct LocalizedInstituteAccessServer {
        let baseURLString: String
        let displayName: String

        init(_ server: DiscoveryData.InstituteAccessServer) {
            baseURLString = server.baseURLString
            displayName = server.displayName.string(for: Locale.current)
        }
    }

    struct LocalizedOrganization {
        let orgId: String
        let displayName: String
        let keywordList: String
        let secureInternetHome: String

        init(_ organization: DiscoveryData.Organization) {
            orgId = organization.orgId
            displayName = organization.displayName.string(for: Locale.current)
            keywordList = organization.keywordList?.string(for: Locale.current) ?? ""
            secureInternetHome = organization.secureInternetHome
        }
    }

    private let serverDiscoveryService: ServerDiscoveryService?
    private let scope: Scope

    private var instituteAccessServers: [LocalizedInstituteAccessServer] = []
    private var organizations: [LocalizedOrganization] = []
    private var searchQuery: String = ""
    private var isLoadInProgress: Bool = false

    private var rows: [Row] = []

    init(serverDiscoveryService: ServerDiscoveryService?, scope: Scope) {
        precondition(scope == .serverByURLOnly || serverDiscoveryService != nil)
        self.serverDiscoveryService = serverDiscoveryService
        self.scope = scope
    }

    func setSearchQuery(_ searchQuery: String) {
        self.searchQuery = searchQuery
        update()
    }

    func load(from origin: DiscoveryDataFetcher.DataOrigin) -> Promise<Void> {
        guard !isLoadInProgress else {
            return Promise(error: SearchViewModelError.cannotLoadWhenPreviousLoadIsInProgress)
        }
        switch scope {
        case .serverByURLOnly:
            // Nothing to load
            return Promise.value(())
        case .instituteAccessOrServerByURL:
            // Load server list only
            guard let serverDiscoveryService = serverDiscoveryService else {
                fatalError("serverDiscoveryService can't be nil for scope \(scope)")
            }
            isLoadInProgress = true
            return firstly {
                serverDiscoveryService.getServers(from: origin)
            }.map { [weak self] servers in
                guard let self = self else { return }
                self.instituteAccessServers = servers.localizedInstituteAccessServers().sorted()
                self.update()
            }.ensure { [weak self] in
                self?.isLoadInProgress = false
            }
        case .all:
            // Load server list and org list in parallel
            isLoadInProgress = true
            guard let serverDiscoveryService = serverDiscoveryService else {
                fatalError("serverDiscoveryService can't be nil for scope \(scope)")
            }
            return firstly {
                when(fulfilled:
                    serverDiscoveryService.getServers(from: origin),
                     serverDiscoveryService.getOrganizations(from: origin))
            }.map { [weak self] servers, organizations in
                guard let self = self else { return }
                self.instituteAccessServers = servers.localizedInstituteAccessServers().sorted()
                self.organizations = organizations.localizedOrganizations().sorted()
                self.update()
            }.ensure { [weak self] in
                self?.isLoadInProgress = false
            }
        }
    }

    func numberOfRows() -> Int {
        return rows.count
    }

    func row(at index: Int) -> Row {
        return rows[index]
    }
}

private extension SearchViewModel {
    func update() {
        let computedRows: [Row] = Self.serverByAddressRows(searchQuery: searchQuery)
            + Self.instituteAccessRows(searchQuery: searchQuery, from: instituteAccessServers)
            + Self.organizationRows(searchQuery: searchQuery, from: organizations)
        assert(computedRows == computedRows.sorted(), "computedRows is not ordered correctly")
        let diff = computedRows.rowsDifference(from: self.rows)
        self.rows = computedRows
        self.delegate?.rowsChanged(changes: diff)
    }

    static func serverByAddressRows(searchQuery: String) -> [Row] {
        let hasTwoOrMoreDots = searchQuery.filter { $0 == "." }.count >= 2
        if hasTwoOrMoreDots {
            let url = searchQuery.hasPrefix("https://") ?
                searchQuery : ("https://" + searchQuery)
            return [.addingServerByURLSectionHeader,
                    .addingServerByURL(url)]
        }
        return []
    }

    static func instituteAccessRows(searchQuery: String,
                                    from sortedList: [LocalizedInstituteAccessServer])
        -> [Row] {
        let matchingServerRows: [Row] = sortedList
            .filter {
                searchQuery.isEmpty ||
                $0.displayName.localizedCaseInsensitiveContains(searchQuery)
            }.map { .instituteAccessServer($0) }
        return matchingServerRows.isEmpty ?
            [] :
            [ .instituteAccessServerSectionHeader ] + matchingServerRows
    }

    static func organizationRows(searchQuery: String,
                                 from sortedList: [LocalizedOrganization])
        -> [Row] {
        let matchingServerRows: [Row] = sortedList
            .filter {
                searchQuery.isEmpty ||
                $0.displayName.localizedCaseInsensitiveContains(searchQuery) ||
                $0.keywordList.localizedCaseInsensitiveContains(searchQuery)
            }.map { .secureInternetOrg($0) }
        return matchingServerRows.isEmpty ?
            [] :
            [ .secureInternetOrgSectionHeader ] + matchingServerRows
    }
}

extension SearchViewModel.LocalizedInstituteAccessServer: Comparable {
    static func < (lhs: SearchViewModel.LocalizedInstituteAccessServer,
                   rhs: SearchViewModel.LocalizedInstituteAccessServer) -> Bool {
        return lhs.displayName < rhs.displayName
    }
}

extension SearchViewModel.LocalizedOrganization: Comparable {
    static func < (lhs: SearchViewModel.LocalizedOrganization,
                   rhs: SearchViewModel.LocalizedOrganization) -> Bool {
        return lhs.displayName < rhs.displayName
    }
}

private extension DiscoveryData.Servers {
    func localizedInstituteAccessServers() -> [SearchViewModel.LocalizedInstituteAccessServer] {
        instituteAccessServers.map { SearchViewModel.LocalizedInstituteAccessServer($0) }
    }
}

private extension DiscoveryData.Organizations {
    func localizedOrganizations() -> [SearchViewModel.LocalizedOrganization] {
        organizations.map { SearchViewModel.LocalizedOrganization($0) }
    }
}
