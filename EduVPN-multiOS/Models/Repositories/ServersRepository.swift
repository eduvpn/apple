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
    
    private typealias Bytes = [UInt8]
    
    private func verify(message: Bytes, publicKey: Bytes, signature: Bytes) -> Bool {
        guard publicKey.count == 32 else {
            return false
        }
        
        return 0 == crypto_sign_verify_detached(signature,
                                                message,
                                                UInt64(message.count),
                                                publicKey)
    }
    
    // Load
    
    func load(with organization: Organization) {
        guard let (target, sigTarget) = try? pickStaticTargets(for: organization) else {
            return
        }
        
        let provider = MoyaProvider<StaticService>(manager: MoyaProvider<StaticService>.ephemeralAlamofireManager())
        
        provider
//            .request(target: sigTarget)
//            .then(validateSodiumSignature)
//            .then { provider.request(target: target).then(self.verifyResponse(signature: $0)) }
            .request(target: target)
            .then(decodeServers)
            .then(parseServers(organizationIdentifier: organization.identifier!))
            .recover {
                #if os(iOS)
                (UIApplication.shared.delegate as? AppDelegate)?.appCoordinator.showError($0)
                #elseif os(macOS)
                (NSApp.delegate as? AppDelegate)?.appCoordinator.showError($0)
                #endif
            }
    }
    
    // Load steps
    
    private func validateSodiumSignature(response: Moya.Response) throws -> Promise<Data> {
        if let signature = Data(base64Encoded: response.data) {
            return Promise.value(signature)
        } else {
            throw AppCoordinatorError.sodiumSignatureFetchFailed
        }
    }
    
    private func verifyResponse(signature: Data) -> (Moya.Response) throws -> Promise<Moya.Response> {
        return { response in
            guard let publicKey = StaticService.publicKey else {
                throw AppCoordinatorError.sodiumSignatureVerifyFailed
            }
            let isVerified: Bool

            if #available(iOS 13.0, macOS 10.15, *) {
                let cryptoKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicKey)
                isVerified = cryptoKey.isValidSignature(signature, for: response.data)
            } else {
                isVerified = self.verify(message: Array(response.data),
                                         publicKey: Array(publicKey),
                                         signature: Array(signature))
            }
            
            guard isVerified else {
                throw AppCoordinatorError.sodiumSignatureVerifyFailed
            }
            
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
