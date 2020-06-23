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

class SearchViewModel {
    weak var delegate: SearchViewModelDelegate?

    enum Row: ViewModelRow {
        case addingServerByURLSectionHeader
        case addingServerByURL(String)
        case instituteAccessServerSectionHeader
        case instituteAccessServer(InstituteAccessServer)
        case secureInternetOrgSectionHeader
        case secureInternetOrg(Organization)

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

        var displayName: String {
            switch self {
            case .instituteAccessServer(let server): return server.displayName
            case .secureInternetOrg(let organization): return organization.displayName
            default: return ""
            }
        }
    }

    enum Scope {
        case serverByURLOnly
        case instituteAccessOrServerByURL
        case all
    }

    struct InstituteAccessServer: Comparable {
        let baseURLString: String
        let displayName: String

        init(_ server: DiscoveryData.InstituteAccessServer) {
            baseURLString = server.baseURLString
            displayName = server.displayName.string(for: Locale.current)
        }

        static func < (lhs: InstituteAccessServer, rhs: InstituteAccessServer) -> Bool {
            return lhs.displayName < rhs.displayName
        }
    }

    struct Organization: Comparable {
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

        static func < (lhs: Organization, rhs: Organization) -> Bool {
            return lhs.displayName < rhs.displayName
        }
    }

    private let serverDiscoveryService: ServerDiscoveryService

    private var scope: Scope = .serverByURLOnly
    private var sortedInstituteAccessServers: [InstituteAccessServer] = []
    private var sortedOrganizations: [Organization] = []
    private var searchQuery: String = ""

    private var rows: [Row] = []

    init(serverDiscoveryService: ServerDiscoveryService) {
        self.serverDiscoveryService = serverDiscoveryService
        serverDiscoveryService.addServersChangeHandler { [weak self] (servers) in
            self?.setSortedInstituteAccessServers(from: servers)
        }
        serverDiscoveryService.addOrganizationsChangeHandler { [weak self] (organizations) in
            self?.setSortedOrganizations(from: organizations)
        }
    }

    func setSearchQuery(_ searchQuery: String) {
        // Should debounce
        self.searchQuery = searchQuery
    }

    func setScope(_ scope: Scope) {
        guard scope != self.scope else { return }
        switch scope {
        case .serverByURLOnly:
            setSortedInstituteAccessServers(from: nil)
            setSortedOrganizations(from: nil)
        case .instituteAccessOrServerByURL:
            setSortedInstituteAccessServers(from: serverDiscoveryService.servers)
            setSortedOrganizations(from: nil)
        case .all:
            setSortedInstituteAccessServers(from: serverDiscoveryService.servers)
            setSortedOrganizations(from: serverDiscoveryService.organizations)
        }
        self.scope = scope
        update()
    }

    private func setSortedInstituteAccessServers(from servers: DiscoveryData.Servers?) {
        sortedInstituteAccessServers = (servers?.instituteAccessServers ?? [])
            .map { InstituteAccessServer($0) }
            .sorted()
    }

    private func setSortedOrganizations(from organizations: DiscoveryData.Organizations?) {
        sortedOrganizations = (organizations?.organizations ?? [])
            .map { Organization($0) }
            .sorted()
    }

    func refreshFromServer() -> Promise<Void> {
        var refreshingPromises: [Promise<Void>] = []
        if scope == .instituteAccessOrServerByURL || scope == .all {
            refreshingPromises.append(serverDiscoveryService.refreshServers())
        }
        if scope == .all {
            refreshingPromises.append(serverDiscoveryService.refreshOrganizations())
        }
        return when(fulfilled: refreshingPromises)
    }

    func numberOfRows() -> Int {
        return rows.count
    }

    func row(at index: Int) -> Row {
        return rows[index]
    }

    private func update() {
        let computedRows: [Row] = Self.serverByAddressRows(searchQuery: searchQuery)
            + Self.instituteAccessRows(searchQuery: searchQuery, from: sortedInstituteAccessServers)
            + Self.organizationRows(searchQuery: searchQuery, from: sortedOrganizations)
        assert(computedRows == computedRows.sorted(), "computedRows is not ordered correctly")
        let diff = computedRows.rowsDifference(from: self.rows)
        self.rows = computedRows
        self.delegate?.rowsChanged(changes: diff)
    }

    private static func serverByAddressRows(searchQuery: String) -> [Row] {
        let hasTwoOrMoreDots = searchQuery.filter { $0 == "." }.count > 2
        if hasTwoOrMoreDots {
            let url = searchQuery.hasPrefix("https://") ?
                searchQuery : ("https://" + searchQuery)
            return [.addingServerByURLSectionHeader,
                    .addingServerByURL(url)]
        }
        return []
    }

    private static func instituteAccessRows(searchQuery: String, from sortedList: [InstituteAccessServer])
        -> [Row] {
        let matchingServerRows: [Row] = sortedList
            .filter {
                searchQuery.isEmpty ||
                $0.displayName.contains(searchQuery)
            }.map { .instituteAccessServer($0) }
        return matchingServerRows.isEmpty ?
            [] :
            [ .instituteAccessServerSectionHeader ] + matchingServerRows
    }

    private static func organizationRows(searchQuery: String, from sortedList: [Organization])
        -> [Row] {
        let matchingServerRows: [Row] = sortedList
            .filter {
                searchQuery.isEmpty ||
                $0.displayName.contains(searchQuery) ||
                $0.keywordList.contains(searchQuery)
            }.map { .secureInternetOrg($0) }
        return matchingServerRows.isEmpty ?
            [] :
            [ .secureInternetOrgSectionHeader ] + matchingServerRows
    }
}
