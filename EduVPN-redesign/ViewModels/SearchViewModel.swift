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
        case instituteAccessServerSectionHeader
        case instituteAccessServer(LocalizedInstituteAccessServer)
        case secureInternetOrgSectionHeader
        case secureInternetOrg(LocalizedOrganization)
        case serverByURLSectionHeader
        case serverByURL(String)
        case noResults

        var rowKind: ViewModelRowKind {
            switch self {
            case .instituteAccessServerSectionHeader: return .instituteAccessServerSectionHeaderKind
            case .instituteAccessServer: return .instituteAccessServerKind
            case .secureInternetOrgSectionHeader: return .secureInternetOrgSectionHeaderKind
            case .secureInternetOrg: return .secureInternetOrgKind
            case .serverByURLSectionHeader: return .serverByURLSectionHeaderKind
            case .serverByURL: return .serverByURLKind
            case .noResults: return .noResultsKind
            }
        }

        var displayText: String {
            switch self {
            case .instituteAccessServer(let server): return server.displayName
            case .secureInternetOrg(let organization): return organization.displayName
            case .serverByURL(let urlString): return urlString
            default: return ""
            }
        }

        var baseURL: URL? {
            switch self {
            case .instituteAccessServer(let server): return URL(string: server.baseURLString)
            case .secureInternetOrg(let organization): return URL(string: organization.secureInternetHome)
            case .serverByURL(let urlString): return URL(string: urlString)
            default: return nil
            }
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

    private let serverDiscoveryService: ServerDiscoveryService
    private let shouldIncludeOrganizations: Bool

    private var instituteAccessServers: [LocalizedInstituteAccessServer] = []
    private var organizations: [LocalizedOrganization] = []
    private var searchQuery: String = ""
    private var isLoadInProgress: Bool = false

    private var rows: [Row] = []

    init(serverDiscoveryService: ServerDiscoveryService, shouldIncludeOrganizations: Bool) {
        self.serverDiscoveryService = serverDiscoveryService
        self.shouldIncludeOrganizations = shouldIncludeOrganizations
    }

    func setSearchQuery(_ searchQuery: String) {
        self.searchQuery = searchQuery
        update()
    }

    func load(from origin: DiscoveryDataFetcher.DataOrigin) -> Promise<Void> {
        guard !isLoadInProgress else {
            return Promise(error: SearchViewModelError.cannotLoadWhenPreviousLoadIsInProgress)
        }
        if shouldIncludeOrganizations {
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
        } else {
            return firstly {
                serverDiscoveryService.getServers(from: origin)
            }.map { [weak self] servers in
                guard let self = self else { return }
                self.instituteAccessServers = servers.localizedInstituteAccessServers().sorted()
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
        var computedRows: [Row] = []
        computedRows.append(contentsOf: Self.instituteAccessRows(searchQuery: searchQuery, from: instituteAccessServers))
        computedRows.append(contentsOf: Self.organizationRows(searchQuery: searchQuery, from: organizations))
        computedRows.append(contentsOf: Self.serverByAddressRows(searchQuery: searchQuery))
        if computedRows.isEmpty {
            computedRows.append(.noResults)
        }
        assert(computedRows == computedRows.sorted(), "computedRows is not ordered correctly")
        let diff = computedRows.rowsDifference(from: self.rows)
        self.rows = computedRows
        self.delegate?.rowsChanged(changes: diff)
    }

    static func serverByAddressRows(searchQuery: String) -> [Row] {
        let hasTwoOrMoreDots = searchQuery.filter { $0 == "." }.count >= 2
        if hasTwoOrMoreDots {
            var url = searchQuery
            if !url.hasPrefix("https://") {
                url = "https://" + url
            }
            if !url.hasSuffix("/") {
                url += "/"
            }
            return [.serverByURLSectionHeader,
                    .serverByURL(url)]
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
