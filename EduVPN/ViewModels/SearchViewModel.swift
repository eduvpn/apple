//
//  SearchViewModel.swift
//  EduVPN
//
//  Created by Johan Kool on 28/05/2020.
//

import Foundation
import PromiseKit

protocol SearchViewModelDelegate: AnyObject {
    func searchViewModel(_ model: SearchViewModel, rowsChanged changes: RowsDifference<SearchViewModel.Row>)
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
        case serverByURL(DiscoveryData.BaseURLString)
        case noResults

        var rowKind: ViewModelRowKind {
            switch self {
            case .instituteAccessServerSectionHeader: return .instituteAccessServerSectionHeaderKind
            case .instituteAccessServer: return .instituteAccessServerKind
            case .secureInternetOrgSectionHeader: return .secureInternetOrgSectionHeaderKind
            case .secureInternetOrg: return .secureInternetOrgKind
            case .serverByURLSectionHeader: return .otherServerSectionHeaderKind
            case .serverByURL: return .serverByURLKind
            case .noResults: return .noResultsKind
            }
        }

        var displayText: String {
            switch self {
            case .instituteAccessServer(let server): return server.localizedDisplayName
            case .secureInternetOrg(let organization): return organization.localizedDisplayName
            case .serverByURL(let baseURLString): return baseURLString.toString()
            default: return ""
            }
        }

        var baseURLString: DiscoveryData.BaseURLString? {
            switch self {
            case .instituteAccessServer(let server): return server.baseURLString
            case .secureInternetOrg(let organization): return organization.secureInternetHome
            case .serverByURL(let baseURLString): return baseURLString
            default: return nil
            }
        }
    }

    struct LocalizedInstituteAccessServer {
        let baseURLString: DiscoveryData.BaseURLString
        let displayName: LanguageMappedString
        let keywordList: LanguageMappedString?
        let localizedDisplayName: String

        init(_ server: DiscoveryData.InstituteAccessServer) {
            baseURLString = server.baseURLString
            displayName = server.displayName
            keywordList = server.keywordList
            localizedDisplayName = server.displayName.stringForCurrentLanguage()
        }
    }

    struct LocalizedOrganization {
        let orgId: String
        let displayName: LanguageMappedString
        let keywordList: LanguageMappedString?
        let localizedDisplayName: String
        let secureInternetHome: DiscoveryData.BaseURLString

        init(_ organization: DiscoveryData.Organization) {
            orgId = organization.orgId
            displayName = organization.displayName
            keywordList = organization.keywordList
            localizedDisplayName = organization.displayName.stringForCurrentLanguage()
            secureInternetHome = organization.secureInternetHome
        }
    }

    private let serverDiscoveryService: ServerDiscoveryService
    private let shouldIncludeOrganizations: Bool

    private var instituteAccessServers: [LocalizedInstituteAccessServer] = []
    private var secureInternetServersMap: [DiscoveryData.BaseURLString: DiscoveryData.SecureInternetServer] = [:]
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
        isLoadInProgress = true
        if shouldIncludeOrganizations {
            return firstly {
                when(fulfilled:
                    serverDiscoveryService.getServers(from: origin),
                     serverDiscoveryService.getOrganizations(from: origin))
            }.map { [weak self] servers, organizations in
                guard let self = self else { return }
                self.instituteAccessServers = servers.localizedInstituteAccessServers().sorted()
                self.secureInternetServersMap = servers.secureInternetServersMap
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

    func wayfSkippingInfo(for row: Row) -> ServerAuthService.WAYFSkippingInfo? {
        if case .secureInternetOrg(let organization) = row {
            if let authURLTemplate = secureInternetServersMap[organization.secureInternetHome]?.authenticationURLTemplate {
                return ServerAuthService.WAYFSkippingInfo(
                    authURLTemplate: authURLTemplate, orgId: organization.orgId)
            }
        }
        return nil
    }

    func hasResults() -> Bool {
        return !rows.isEmpty && row(at: 0) != .noResults
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
        self.delegate?.searchViewModel(self, rowsChanged: diff)
    }

    static func serverByAddressRows(searchQuery: String) -> [Row] {
        let hasTwoOrMoreDots = searchQuery.filter { $0 == "." }.count >= 2
        if hasTwoOrMoreDots {
            var url = searchQuery.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if !url.hasPrefix("https://") {
                url = "https://" + url
            }
            if !url.hasSuffix("/") {
                url += "/"
            }
            // This URL shall be used as if it was a base URL appearing in a discovery data file
            let baseURLString = DiscoveryData.BaseURLString(urlString: url)
            return [.serverByURLSectionHeader,
                    .serverByURL(baseURLString)]
        }
        return []
    }

    static func instituteAccessRows(searchQuery: String,
                                    from sortedList: [LocalizedInstituteAccessServer])
        -> [Row] {
        let matchingServerRows: [Row] = sortedList
            .filter {
                searchQuery.isEmpty ||
                    $0.displayName.matches(searchQuery: searchQuery) ||
                    ($0.keywordList?.matches(searchQuery: searchQuery) ?? false)
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
                $0.displayName.matches(searchQuery: searchQuery) ||
                ($0.keywordList?.matches(searchQuery: searchQuery) ?? false)
            }.map { .secureInternetOrg($0) }
        return matchingServerRows.isEmpty ?
            [] :
            [ .secureInternetOrgSectionHeader ] + matchingServerRows
    }
}

extension SearchViewModel.LocalizedInstituteAccessServer: Equatable {
    static func == (lhs: SearchViewModel.LocalizedInstituteAccessServer, rhs: SearchViewModel.LocalizedInstituteAccessServer) -> Bool {
        return lhs.baseURLString == rhs.baseURLString
    }
}

extension SearchViewModel.LocalizedInstituteAccessServer: Comparable {
    static func < (lhs: SearchViewModel.LocalizedInstituteAccessServer,
                   rhs: SearchViewModel.LocalizedInstituteAccessServer) -> Bool {
        return lhs.localizedDisplayName < rhs.localizedDisplayName
    }
}

extension SearchViewModel.LocalizedOrganization: Equatable {
    static func == (lhs: SearchViewModel.LocalizedOrganization, rhs: SearchViewModel.LocalizedOrganization) -> Bool {
        return lhs.orgId == rhs.orgId
    }
}

extension SearchViewModel.LocalizedOrganization: Comparable {
    static func < (lhs: SearchViewModel.LocalizedOrganization,
                   rhs: SearchViewModel.LocalizedOrganization) -> Bool {
        return lhs.localizedDisplayName < rhs.localizedDisplayName
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
