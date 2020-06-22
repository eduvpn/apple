//
//  OrganizationsLoader.swift
//  eduVPN
//

import Foundation
import Moya
import PromiseKit
import CryptoKit

enum OrganizationsLoaderError: LocalizedError {
    case missingStaticTargets
    case missingPublicKey
    
    var errorDescription: String? {
        switch self {
        case .missingStaticTargets:
            return NSLocalizedString("Static target configuration is incomplete.", comment: "")
        case .missingPublicKey:
            return NSLocalizedString("Missing public key", comment: "")
            
        }
    }
}

class OrganizationsLoader {
    
    let config: Config
    
    init(config: Config) {
        self.config = config
    }
    
    private func pickStaticTargets() throws -> (StaticService, StaticService) {
        let target: StaticService!
        let sigTarget: StaticService!
        
        target = StaticService(type: .organizationList, config: config)
        sigTarget = StaticService(type: .organizationListSignature, config: config)
        
        if target == nil || sigTarget == nil {
            throw OrganizationsLoaderError.missingStaticTargets
        }
        
        return (target, sigTarget)
    }
    
    // Load
    
    func load() -> Promise<OrganizationsModel> {
        guard let (target, sigTarget) = try? pickStaticTargets() else {
            return Promise(error: OrganizationsLoaderError.missingStaticTargets)
        }
        
        let provider = MoyaProvider<StaticService>(session: MoyaProvider<StaticService>.ephemeralAlamofireSession())
              
        return provider
            .request(target: sigTarget)
            .then(validateMinisignSignature)
            .then { provider.request(target: target).then(self.verifyResponse(signatureWithMetadata: $0)) }
            .then(decodeOrganizations)
 
//            .then(parseOrganizations())
//            .recover {
//                #if os(iOS)
//                (UIApplication.shared.delegate as? AppDelegate)?.appCoordinator.showError($0)
//                #elseif os(macOS)
//                (NSApp.delegate as? AppDelegate)?.appCoordinator.showError($0)
//                #endif
//            }
    }
    
    // Load steps
    
    private func validateMinisignSignature(response: Moya.Response) throws -> Promise<Data> {
        let data = try SignatureHelper.minisignSignatureFromFile(data: response.data)
        return Promise.value(data)
    }
    
    private func verifyResponse(signatureWithMetadata: Data) -> (Moya.Response) throws -> Promise<Moya.Response> {
        return { response in
            let signaturePublicKeys = self.config.discovery.signaturePublicKeys
            try SignatureHelper.verify(signatureWithMetadata: signatureWithMetadata, data: response.data, publicKeyWithMetadata: signaturePublicKeys.first!)
            return Promise.value(response)
        }
    }
    
    private func decodeOrganizations(response: Moya.Response) -> Promise<OrganizationsModel> {
        return response.mapResponse()
    }
    
}
