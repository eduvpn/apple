//
//  StaticService.swift
//  eduVPN
//

import Foundation
import Moya

struct StaticService: TargetType, AcceptJson, EmptySampleData {
    
    enum StaticServiceType {
        case organizationList
        case organizationListSignature
        case serverList
        case serverListSignature
    }
    
    init?(type: StaticService.StaticServiceType, config: Config) {
        guard let url = config.discovery?.url(forServiceType: type), let baseURL = url.baseURL else {
            return nil
        }
        
        self.baseURL = baseURL
        self.path = baseURL.path
    }
    
    var method: Moya.Method { return .get }
    var task: Task { return .requestPlain }
    
    var baseURL: URL
    var path: String
    
}
