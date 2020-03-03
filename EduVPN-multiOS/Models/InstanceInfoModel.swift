//
//  InstanceInfoModel.swift
//  eduVPN
//

import Foundation
import AppAuth

struct InstanceInfoModel: Decodable {
    
    var authorizationEndpoint: URL
    var tokenEndpoint: URL
    var apiBaseUrl: URL
}

extension InstanceInfoModel {
    
    enum InstanceInfoModelKeys: String, CodingKey {
        case api
        case apiInfo = "http://eduvpn.org/api#2"
        case authorizationEndpoint = "authorization_endpoint"
        case tokenEndpoint = "token_endpoint"
        case apiBaseUrl = "api_base_uri"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: InstanceInfoModelKeys.self)
        
        let apiContainer = try container.nestedContainer(keyedBy: InstanceInfoModelKeys.self, forKey: .api)
        let apiInfoContainer = try apiContainer.nestedContainer(keyedBy: InstanceInfoModelKeys.self, forKey: .apiInfo)
        
        let authorizationEndpoint = try apiInfoContainer.decode(URL.self, forKey: .authorizationEndpoint)
        let tokenEndpoint = try apiInfoContainer.decode(URL.self, forKey: .tokenEndpoint)
        let apiBaseUrl = try apiInfoContainer.decode(URL.self, forKey: .apiBaseUrl)
        
        self.init(authorizationEndpoint: authorizationEndpoint, tokenEndpoint: tokenEndpoint, apiBaseUrl: apiBaseUrl)
    }
}

extension InstanceInfoModel: Hashable {
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(apiBaseUrl)
    }
    
    static func == (lhs: InstanceInfoModel, rhs: InstanceInfoModel) -> Bool {
        return lhs.apiBaseUrl == rhs.apiBaseUrl
    }
}
