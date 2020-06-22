//
//  ServerDiscoveryService.swift
//  EduVPN
//

import Foundation
import PromiseKit

class ServerDiscoveryService {

    // We use handlers instead of delegates because:
    //  - We can have more than one view model watching for changes
    //  - The view models watching for changes can be structs, not classes

    typealias ServersChangeHandler = (DiscoveryData.Servers) -> Void
    typealias OrganizationsChangeHandler = (DiscoveryData.Organizations) -> Void

    var servers: DiscoveryData.Servers? {
        // Parsed server data is cached in memory because
        // mutiple view controllers will need access to this data
        if _servers == nil {
            if let cachedData = DiscoveryDataFetcher.cachedData(
                dataURL: discoveryConfig.serverList,
                signatureURL: discoveryConfig.serverListSignature,
                publicKeys: discoveryConfig.signaturePublicKeys) {
                _servers = try? Self.parseServerData(cachedData)
            }
        }
        return _servers
    }

    var organizations: DiscoveryData.Organizations? {
        // Parsed organization data is not cached in memory because
        // only one view controller will need access to this data
        if let cachedData = DiscoveryDataFetcher.cachedData(
            dataURL: discoveryConfig.organizationList,
            signatureURL: discoveryConfig.organizationListSignature,
            publicKeys: discoveryConfig.signaturePublicKeys) {
            return try? Self.parseOrganizationData(cachedData)
        }
        return nil
    }

    private var serversChangeHandlers: [UUID: ServersChangeHandler] = [:]
    private var organizationsChangeHandlers: [UUID: OrganizationsChangeHandler] = [:]

    private var discoveryConfig: DiscoveryConfig
    private var _servers: DiscoveryData.Servers?

    init(discoveryConfig: DiscoveryConfig) {
        self.discoveryConfig = discoveryConfig
    }

    func addServersChangeHandler(_ handler: @escaping ServersChangeHandler) -> UUID {
        let uuid = UUID()
        serversChangeHandlers[uuid] = handler
        return uuid
    }

    func removeServersChangeHandler(_ uuid: UUID) {
        serversChangeHandlers.removeValue(forKey: uuid)
    }

    func addOrganizationsChangeHandler(_ handler: @escaping OrganizationsChangeHandler) -> UUID {
        let uuid = UUID()
        organizationsChangeHandlers[uuid] = handler
        return uuid
    }

    func removeOrganizationsChangeHandler(_ uuid: UUID) {
        organizationsChangeHandlers.removeValue(forKey: uuid)
    }

    /// Contacts the server, refreshes the data, and notifies handlers
    func refreshServers() -> Promise<Void> {
        return DiscoveryDataFetcher.fetch(
            dataURL: discoveryConfig.serverList,
            signatureURL: discoveryConfig.serverListSignature,
            publicKeys: discoveryConfig.signaturePublicKeys)
            .map { data in
                let servers = try Self.parseServerData(data)
                self._servers = servers
                for handler in self.serversChangeHandlers.values {
                    handler(servers)
                }
            }
    }

    /// Contacts the server, refreshes the data, and notifies handlers
    func refreshOrganizations() -> Promise<Void> {
        return DiscoveryDataFetcher.fetch(
            dataURL: discoveryConfig.organizationList,
            signatureURL: discoveryConfig.organizationListSignature,
            publicKeys: discoveryConfig.signaturePublicKeys)
            .map { data in
                let organizations = try Self.parseOrganizationData(data)
                for handler in self.organizationsChangeHandlers.values {
                    handler(organizations)
                }
            }
    }

    private static func parseServerData(_ data: Data) throws -> DiscoveryData.Servers {
        return try JSONDecoder().decode(DiscoveryData.Servers.self, from: data)
    }

    private static func parseOrganizationData(_ data: Data) throws -> DiscoveryData.Organizations {
        return try JSONDecoder().decode(DiscoveryData.Organizations.self, from: data)
    }
}
