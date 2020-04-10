//
//  ServersRepository.swift
//  eduVPN
//

import CoreData
import Foundation
import libsodium
import Moya
import PromiseKit
import CryptoKit

struct ServersRepository {
    let loader = ServersLoader()
    let refresher = InstanceRefresher()
}

enum ServersLoaderError: Error {
    case staticTargetError
}

// MARK: - ServersLoader

class ServersLoader {
    
    weak var persistentContainer: NSPersistentContainer!
    
    private func pickStaticTargets(for organization: Organization) throws -> (StaticService, StaticService) {
        let target: StaticService! = StaticService(type: .organizationServerList(organization: organization))
        let sigTarget: StaticService! = StaticService(type: .organizationServerListSignature(organization: organization))
        
        if target == nil || sigTarget == nil {
            throw AppCoordinatorError.missingStaticTargets
        }
        
        return (target, sigTarget)
    }
    
    // Load
    
    func load(with organization: Organization) -> Promise<Void> {
        guard let (target, sigTarget) = try? pickStaticTargets(for: organization), let identifier = organization.identifier else {
            return Promise(error: ServersLoaderError.staticTargetError)
        }
        
        let provider = MoyaProvider<StaticService>(manager: MoyaProvider<StaticService>.ephemeralAlamofireManager())
        
        return provider
            .request(target: sigTarget)
            .then(validateMinisignSignature)
            .then { provider.request(target: target).then(self.verifyResponse(signatureWithMetadata: $0)) }
            .then(decodeServers)
            .then(parseServers(organizationIdentifier: identifier))
    }
    
    // Load steps
    
    private func validateMinisignSignature(response: Moya.Response) throws -> Promise<Data> {
        let data = try SignatureHelper.minisignSignatureFromFile(data: response.data)
        return Promise.value(data)
    }
    
    private func verifyResponse(signatureWithMetadata: Data) -> (Moya.Response) throws -> Promise<Moya.Response> {
        return { response in
            try SignatureHelper.verify(signatureWithMetadata: signatureWithMetadata, data: response.data)
            return Promise.value(response)
        }
    }
    
    private func decodeServers(response: Moya.Response) -> Promise<ServersModel> {
        return response.mapResponse()
    }
    
    //swiftlint:disable:next function_body_length
    private func parseServers(organizationIdentifier: String) -> (ServersModel) -> Promise<Void> {
        return { servers in
            let serverIdentifiers = servers.servers.map { $0.baseUri.absoluteString }
            return Promise(resolver: { seal in
                self.persistentContainer.performBackgroundTask { context in
                    let serverGroupIdentifier = organizationIdentifier
                    
                    let organization = try! Organization.findFirstInContext(context, predicate: NSPredicate(format: "identifier == %@", serverGroupIdentifier))//swiftlint:disable:this force_try
                    
                    let group = try! InstanceGroup.findFirstInContext(context, predicate: NSPredicate(format: "discoveryIdentifier == %@", serverGroupIdentifier)) ?? InstanceGroup(context: context)//swiftlint:disable:this force_try

//                    guard group.seq < servers.seq else {
//                        seal.reject(AppCoordinatorError.discoverySeqNotIncremented)
//                        return
//                    }

                    group.discoveryIdentifier = serverGroupIdentifier
//                    group.authorizationType = servers.authorizationType.rawValue

                    let authServer = AuthServer.upsert(with: servers, on: context)

                    let updatedServers = group.instances.filter {
                        guard let baseUri = $0.baseUri else { return false }
                        return serverIdentifiers.contains(baseUri)
                    }

                    updatedServers.forEach {
                        if let baseUri = $0.baseUri {
                            if let updatedModel = servers.servers.first(where: {
                                $0.baseUri.absoluteString == baseUri
                            }) {
//                                $0.providerType = providerType.rawValue
                                $0.authServer = authServer
                                $0.update(with: updatedModel)
                                // TODO update children
                            }
                        }
                    }

                    let updatedServerIdentifiers = updatedServers.compactMap { $0.baseUri}

                    let deletedServers = group.instances.filter {
                        guard let baseUri = $0.baseUri else { return false }
                        return !updatedServerIdentifiers.contains(baseUri)
                    }

                    deletedServers.forEach {
                        context.delete($0)
                    }

                    servers.servers
                        .filter { !updatedServerIdentifiers.contains($0.baseUri.absoluteString) }
                        .forEach { (serverModel: ServerModel) in
                            let newServer = Instance(context: context)
                            group.addToInstances(newServer)
                            organization!.addToServers(newServer)
                            newServer.group = group
                            newServer.providerType = ProviderType.organization.rawValue
                            newServer.isParent = true
                            newServer.authServer = authServer
                            newServer.update(with: serverModel)
                            newServer.updateDisplayAndSortNames()
                            
                            for peerModel in serverModel.peers ?? [] {
                                newServer.isExpanded = false
                                let newPeer = Instance(context: context)
                                group.addToInstances(newPeer)
                                organization!.addToServers(newPeer)
                                newPeer.parent = newServer
                                newPeer.isParent = false
                                newPeer.group = group
                                newPeer.authServer = authServer
                                newPeer.providerType = ProviderType.organization.rawValue
                                newPeer.update(with: peerModel)
                                newPeer.updateDisplayAndSortNames()
                            }
                        }
                    
                    context.saveContextToStore { result in
                        switch result {
                            
                        case .success:
                            seal.fulfill(())
                            
                        case .failure(let error):
                            seal.reject(error)
                            
                        }
                    }
                }
            })
        }
    }
    
}

// MARK: - ServerRefresher

class ServerRefresher {
    
//    let provider = MoyaProvider<DynamicServerService>(manager: MoyaProvider<DynamicServerService>.ephemeralAlamofireManager())
//
//    weak var persistentContainer: NSPersistentContainer!
//
//    func refresh(server: Server) -> Promise<Api> {
//        return firstly { () -> Promise<URL> in
//            guard let baseURL = (server.baseUri.flatMap {URL(string: $0)}) else {
//                throw AppCoordinatorError.urlCreation
//            }
//            return .value(baseURL)
//        }.then { (baseURL) -> Promise<Moya.Response> in
//            return self.provider.request(target: DynamicServerService(baseURL: baseURL))
//        }.then { response -> Promise<ServerInfoModel> in
//            response.mapResponse()
//        }.then { serverInfoModel -> Promise<Api> in
//            return Promise<Api>(resolver: { seal in
//                self.persistentContainer.performBackgroundTask { context in
//                    let authServer = AuthServer.upsert(with: serverInfoModel, on: context)
//                    let api = Api.upsert(with: serverInfoModel, for: server, on: context)
//                    api.authServer = authServer
//
//                    do {
//                        try context.save()
//                    } catch {
//                        seal.reject(error)
//                    }
//
//                    seal.fulfill(api)
//                }
//            })
//        }
//    }
}
