//
//  StaticService.swift
//  EduVPN
//
//  Created by Jeroen Leenarts on 01-08-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

import Foundation

import Moya

struct StaticService: TargetType, AcceptJson {
    enum StaticServiceType {
        case instituteAccess
        case instituteAccessSignature
        case secureInternet
        case secureInternetSignature
        
        var pathKey: String {
            switch self {
            case .instituteAccess:
                return "EduVPNDiscoveryPathInstituteAccess"
            case .instituteAccessSignature:
                return "EduVPNDiscoveryPathInstituteAccess"
            case .secureInternet:
                return "EduVPNDiscoveryPathInstituteAccess"
            case .secureInternetSignature:
                return "EduVPNDiscoveryPathInstituteAccess"
            }
        }
    }
    init?(type: StaticService.StaticServiceType) {
        guard let baseServer: String = Bundle.main.object(forInfoDictionaryKey: "EduVPNDiscoveryServer")  as? String, !baseServer.isEmpty else {
            return nil
        }
        
        guard let baseURL = URL(string: "https://\(baseServer)") else {
            return nil
        }
        
        self.baseURL = baseURL
        
        guard let path: String = Bundle.main.object(forInfoDictionaryKey: type.pathKey)  as? String, !path.isEmpty else {
            return nil
        }

        self.path = path
    }
    
    var method: Moya.Method { return .get }
    var task: Task { return .requestPlain }
    var sampleData: Data { return "".data(using: String.Encoding.utf8)! }

    var baseURL: URL
    var path: String
    
    static var publicKey: Data {
        let base64Signature: String = Bundle.main.object(forInfoDictionaryKey: "EduVPNDiscoverySignaturePublicKey")  as? String ?? ""
        return Data(base64Encoded: base64Signature)!
    }
}
