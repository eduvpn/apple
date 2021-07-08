//
//  ServerDiscoveryService.swift
//  EduVPN
//

import Foundation
import PromiseKit

protocol ServerDiscoveryServiceServersDelegate: AnyObject {
    func serverDiscoveryService(_ service: ServerDiscoveryService,
                                serversChanged servers: DiscoveryData.Servers)
}

class ServerDiscoveryService {

    private var discoveryConfig: DiscoveryConfig

    // Cache of parsed server data, because multiple view controllers
    // might want to access this.
    private var _servers: DiscoveryData.Servers?

    weak var delegate: ServerDiscoveryServiceServersDelegate?

    init(discoveryConfig: DiscoveryConfig) {
        self.discoveryConfig = discoveryConfig
    }

    func getServers(from origin: DiscoveryDataFetcher.DataOrigin)
        -> Promise<DiscoveryData.Servers> {
            if let cachedServers = _servers, origin == .cache {
                return Promise.value(cachedServers)
            }
            return firstly {
                DiscoveryDataFetcher.get(
                    from: origin,
                    dataURL: discoveryConfig.serverList,
                    signatureURL: discoveryConfig.serverListSignature,
                    publicKeys: discoveryConfig.signaturePublicKeys)
            }.map(on: DispatchQueue.global(qos: .userInitiated)) {
                // Perform parsing in a background queue
                return try Self.parseServerData($0)
            }.map(on: DispatchQueue.main) {
                self._servers = $0
                self.delegate?.serverDiscoveryService(self, serversChanged: $0)
                return $0
            }
    }

    func getOrganizations(from origin: DiscoveryDataFetcher.DataOrigin)
        -> Promise<DiscoveryData.Organizations> {
            return firstly {
                DiscoveryDataFetcher.get(
                    from: origin,
                    dataURL: discoveryConfig.organizationList,
                    signatureURL: discoveryConfig.organizationListSignature,
                    publicKeys: discoveryConfig.signaturePublicKeys)
            }.map(on: DispatchQueue.global(qos: .userInitiated)) {
                // Perform parsing in a background queue
                return try Self.parseOrganizationData($0)
            }.map(on: DispatchQueue.main) {
                return $0
            }
    }

    private static func parseServerData(_ data: Data) throws -> DiscoveryData.Servers {
        return try JSONDecoder().decode(DiscoveryData.Servers.self, from: data)
    }

    private static func parseOrganizationData(_ data: Data) throws -> DiscoveryData.Organizations {
        return try JSONDecoder().decode(DiscoveryData.Organizations.self, from: data)
    }
}
