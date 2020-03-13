//
//  OrganizationsRepository.swift
//  eduVPN
//

import CoreData
import Foundation
import libsodium
import Moya
import PromiseKit
import CryptoKit

struct OrganizationsRepository {
    let loader = OrganizationsLoader()
    let refresher = OrganizationRefresher()
}

// MARK: - OrganizationsLoader

class OrganizationsLoader {
    
    weak var persistentContainer: NSPersistentContainer!
    
    private func pickStaticTargets() throws -> (StaticService, StaticService) {
        let target: StaticService!
        let sigTarget: StaticService!
        
        target = StaticService(type: .organizationList)
        sigTarget = StaticService(type: .organizationListSignature)
        
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
    
    func load() {
        guard let (target, sigTarget) = try? pickStaticTargets() else {
            return
        }
        
        let provider = MoyaProvider<StaticService>(manager: MoyaProvider<StaticService>.ephemeralAlamofireManager())
        let instanceGroupIdentifier = "\(target.baseURL.absoluteString)/\(target.path)"
        
        provider
            // TODO: Reenable signature check when available
            // .request(target: sigTarget)
            // .then(validateSodiumSignature)
            // .then { provider.request(target: target).then(self.verifyResponse(signature: $0)) }
            .request(target: target)
            .then(decodeOrganizations)
            //                .then(setProviderTypeForInstances(providerType: providerType))
            .then(parseOrganizations())
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
    
    private func decodeOrganizations(response: Moya.Response) -> Promise<OrganizationsModel> {
        return response.mapResponse()
    }

    //swiftlint:disable:next function_body_length
      private func parseOrganizations() -> (OrganizationsModel) -> Promise<Void> {
          return { organizations in
              let organizationIdentifiers = organizations.organizations.map { $0.infoUri.absoluteString }
              return Promise(resolver: { seal in
                  self.persistentContainer.performBackgroundTask { context in
                    
                    
//                    let foo = Organization.findFirstInContext(context, predicate: <#T##NSPredicate?#>)
//
//                      let group = try! InstanceGroup.findFirstInContext(context, predicate: NSPredicate(format: "discoveryIdentifier == %@", instanceGroupIdentifier)) ?? InstanceGroup(context: context)//swiftlint:disable:this force_try
//
//                      guard group.seq < instances.seq else {
//                          seal.reject(AppCoordinatorError.discoverySeqNotIncremented)
//                          return
//                      }
//
//                      group.discoveryIdentifier = instanceGroupIdentifier
//                      group.authorizationType = organizations.authorizationType.rawValue

//                      let authServer = AuthServer.upsert(with: organizations, on: context)
                    
//                      let updatedInstances = group.instances.filter {
//                          guard let baseUri = $0.baseUri else { return false }
//                          return instanceIdentifiers.contains(baseUri)
//                      }
//
//                      updatedInstances.forEach {
//                          if let baseUri = $0.baseUri {
//                              if let updatedModel = instances.instances.first(where: {
//                                  $0.baseUri.absoluteString == baseUri
//                              }) {
//                                  $0.providerType = providerType.rawValue
//                                  $0.authServer = authServer
//                                  $0.update(with: updatedModel)
//                              }
//                          }
//                      }
//
                      let updatedOrganizationIdentifiers = ["Test"]// = updatedOrganizations.compactMap { $0.baseUri}
//
//                      let deletedOrganizations = group.instances.filter {
//                          guard let baseUri = $0.baseUri else { return false }
//                          return !updatedOrganizationIdentifiers.contains(baseUri)
//                      }
//
//                      deletedOrganizations.forEach {
//                          context.delete($0)
//                      }

                      organizations.organizations
                          .filter { !updatedOrganizationIdentifiers.contains($0.infoUri.absoluteString) }
                          .forEach { (organizationModel: OrganizationModel) in
                              let newOrganization = Organization(context: context)
                              newOrganization.update(with: organizationModel)
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

// MARK: - OrganizationRefresher

class OrganizationRefresher {
    
    let provider = MoyaProvider<DynamicInstanceService>(manager: MoyaProvider<DynamicInstanceService>.ephemeralAlamofireManager())

    weak var persistentContainer: NSPersistentContainer!
    
//    func refresh(instance: Organization) -> Promise<Api> {
//        return firstly { () -> Promise<URL> in
//            guard let baseURL = (instance.baseUri.flatMap {URL(string: $0)}) else {
//                throw AppCoordinatorError.urlCreation
//            }
//            return .value(baseURL)
//        }.then { (baseURL) -> Promise<Moya.Response> in
//            return self.provider.request(target: DynamicInstanceService(baseURL: baseURL))
//        }.then { response -> Promise<InstanceInfoModel> in
//            response.mapResponse()
//        }.then { instanceInfoModel -> Promise<Api> in
//            return Promise<Api>(resolver: { seal in
//                self.persistentContainer.performBackgroundTask { context in
//                    let authServer = AuthServer.upsert(with: instanceInfoModel, on: context)
//                    let api = Api.upsert(with: instanceInfoModel, for: instance, on: context)
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
