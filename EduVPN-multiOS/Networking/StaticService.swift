//
//  StaticService.swift
//  eduVPN
//

import Foundation
import Moya

struct StaticService: TargetType, AcceptJson {
    
    enum StaticServiceType {
        case organizationList
        case organizationListSignature
        case organizationServerList(organization: Organization)
        case organizationServerListSignature(organization: Organization)
        case instituteAccess
        case instituteAccessSignature
        case secureInternet
        case secureInternetSignature
    }
    
    init?(type: StaticService.StaticServiceType) {
        // Workaround different base URLs
        switch type {
        case .organizationList, .organizationListSignature:
            guard let urlString: String = Config.shared.discovery?.path(forServiceType: type), let url = URL(string: urlString), let baseURL = URL(string: "/", relativeTo: url)?.absoluteURL else {
                return nil
            }
            self.baseURL = baseURL
            self.path = url.path
            
        case .organizationServerList(let organization), .organizationServerListSignature(let organization):
            guard let url = organization.serverListUri, let baseURL = URL(string: "/", relativeTo: url)?.absoluteURL else {
                return nil
            }
            self.baseURL = baseURL
            self.path = url.path
            
        default:
            guard let baseURL = Config.shared.discovery?.server else {
                return nil
            }
            
            self.baseURL = baseURL
            
            guard let path: String = Config.shared.discovery?.path(forServiceType: type) else {
                return nil
            }
            
            self.path = path
        }
        
    }
    
    var method: Moya.Method { return .get }
    var task: Task { return .requestPlain }
    var sampleData: Data { return "".data(using: String.Encoding.utf8) ?? Data() }
    
    var baseURL: URL
    var path: String
    
    static var publicKey: Data? { return Config.shared.discovery?.signaturePublicKey }
}
