//
//  InstancesRepository.swift
//  eduVPN
//
//  Created by Aleksandr Poddubny on 30/05/2019.
//  Copyright © 2019 SURFNet. All rights reserved.
//

import CoreData
import Foundation
import libsodium
import Moya
import PromiseKit

struct InstancesRepository {
    
    static let shared = InstancesRepository()
    let loader = InstancesLoader()
    let refresher = InstanceRefresher()
}

// MARK: - InstancesLoader

class InstancesLoader {
    
    weak var persistentContainer: NSPersistentContainer!
    
    private func pickStaticTargets(for providerType: ProviderType) throws -> (StaticService, StaticService) {
        let target: StaticService!
        let sigTarget: StaticService!
        
        switch providerType {
            
        case .instituteAccess:
            target = StaticService(type: .instituteAccess)
            sigTarget = StaticService(type: .instituteAccessSignature)
            
        case .secureInternet:
            target = StaticService(type: .secureInternet)
            sigTarget = StaticService(type: .secureInternetSignature)
            
        case .unknown, .other:
            throw AppCoordinatorError.missingStaticTargets
            
        }
        
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
    
    func load(with providerType: ProviderType) {
        guard let (target, sigTarget) = try? pickStaticTargets(for: providerType) else {
            return
        }
        
        let provider = MoyaProvider<StaticService>()
        let instanceGroupIdentifier = "\(target.baseURL.absoluteString)/\(target.path)"
        
        provider.request(target: sigTarget)
            .then(validateSodiumSignature)
            .then { provider.request(target: target).then(self.verifyResponse(signature: $0)) }
            .then(decodeInstances)
            .then(setProviderTypeForInstances(providerType: providerType))
            .then(parseInstances(instanceGroupIdentifier: instanceGroupIdentifier, providerType: providerType))
            .recover { (UIApplication.shared.delegate as! AppDelegate).appCoordinator.showError($0) }
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
            let isVerified = self.verify(message: Array(response.data),
                                         publicKey: Array(StaticService.publicKey),
                                         signature: Array(signature))
            
            guard isVerified else {
                throw AppCoordinatorError.sodiumSignatureVerifyFailed
            }
            
            return Promise.value(response)
        }
    }
    
    private func decodeInstances(response: Moya.Response) -> Promise<InstancesModel> {
        return response.mapResponse()
    }
    
    private func setProviderTypeForInstances(providerType: ProviderType) -> (InstancesModel) -> Promise<InstancesModel> {
        return {
            var instances = $0
            instances.providerType = providerType
            instances.instances = instances.instances.map {
                var instanceModel = $0
                instanceModel.providerType = providerType
                return instanceModel
            }
            
            return Promise.value(instances)
        }
    }
    
    private func parseInstances(instanceGroupIdentifier: String, providerType: ProviderType) -> (InstancesModel) -> Promise<Void> {
        return { instances in
            let instanceIdentifiers = instances.instances.map { $0.baseUri.absoluteString }
            
            return Promise(resolver: { seal in
                self.persistentContainer.performBackgroundTask { context in
                    let group = try! InstanceGroup.findFirstInContext(context, predicate: NSPredicate(format: "discoveryIdentifier == %@", instanceGroupIdentifier)) ?? InstanceGroup(context: context)//swiftlint:disable:this force_try
                    
                    group.discoveryIdentifier = instanceGroupIdentifier
                    group.authorizationType = instances.authorizationType.rawValue
                    
                    let authServer = AuthServer.upsert(with: instances, on: context)
                    
                    let updatedInstances = group.instances.filter {
                        guard let baseUri = $0.baseUri else { return false }
                        return instanceIdentifiers.contains(baseUri)
                    }
                    
                    updatedInstances.forEach {
                        if let baseUri = $0.baseUri {
                            if let updatedModel = instances.instances.first(where: {
                                $0.baseUri.absoluteString == baseUri
                            }) {
                                $0.providerType = providerType.rawValue
                                $0.authServer = authServer
                                $0.update(with: updatedModel)
                            }
                        }
                    }
                    
                    let updatedInstanceIdentifiers = updatedInstances.compactMap { $0.baseUri}
                    
                    let deletedInstances = group.instances.filter {
                        guard let baseUri = $0.baseUri else { return false }
                        return !updatedInstanceIdentifiers.contains(baseUri)
                    }
                    
                    deletedInstances.forEach {
                        context.delete($0)
                    }
                    
                    instances.instances
                        .filter { !updatedInstanceIdentifiers.contains($0.baseUri.absoluteString) }
                        .forEach { (instanceModel: InstanceModel) in
                            let newInstance = Instance(context: context)
                            group.addToInstances(newInstance)
                            newInstance.group = group
                            newInstance.providerType = providerType.rawValue
                            newInstance.authServer = authServer
                            newInstance.update(with: instanceModel)
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

// MARK: - InstanceRefresher

class InstanceRefresher {
    
    private let provider = MoyaProvider<DynamicInstanceService>()
    weak var persistentContainer: NSPersistentContainer!
    
    func refresh(instance: Instance) -> Promise<Api> {
        let baseUrl = URL(string: instance.baseUri!)!
        
        return provider.request(target: DynamicInstanceService(baseURL: baseUrl))
            .then { response -> Promise<InstanceInfoModel> in response.mapResponse() }
            .then { instanceInfoModel -> Promise<Api> in
                return Promise<Api>(resolver: { seal in
                    self.persistentContainer.performBackgroundTask { context in
                        let authServer = AuthServer.upsert(with: instanceInfoModel, on: context)
                        let api = Api.upsert(with: instanceInfoModel, for: instance, on: context)
                        api.authServer = authServer
                        
                        do {
                            try context.save()
                        } catch {
                            seal.reject(error)
                        }
                        
                        seal.fulfill(api)
                    }
                })
            }
    }
}
