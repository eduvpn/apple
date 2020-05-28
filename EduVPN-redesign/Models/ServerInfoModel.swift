//
//  ServerInfoModel.swift
//  eduVPN
//

import Foundation

struct ServerInfoModel: Decodable {
    
    var authorizationEndpoint: URL
    var tokenEndpoint: URL
    var apiBaseUrl: URL
}

extension ServerInfoModel {
    
    enum ServerInfoModelKeys: String, CodingKey {
        case api
        case apiInfo = "http://eduvpn.org/api#2"
        case authorizationEndpoint = "authorization_endpoint"
        case tokenEndpoint = "token_endpoint"
        case apiBaseUrl = "api_base_uri"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: ServerInfoModelKeys.self)
        
        let apiContainer = try container.nestedContainer(keyedBy: ServerInfoModelKeys.self, forKey: .api)
        let apiInfoContainer = try apiContainer.nestedContainer(keyedBy: ServerInfoModelKeys.self, forKey: .apiInfo)
        
        let authorizationEndpoint = try apiInfoContainer.decode(URL.self, forKey: .authorizationEndpoint)
        let tokenEndpoint = try apiInfoContainer.decode(URL.self, forKey: .tokenEndpoint)
        let apiBaseUrl = try apiInfoContainer.decode(URL.self, forKey: .apiBaseUrl)
        
        self.init(authorizationEndpoint: authorizationEndpoint, tokenEndpoint: tokenEndpoint, apiBaseUrl: apiBaseUrl)
    }
}

extension ServerInfoModel: Hashable {
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(apiBaseUrl)
    }
    
    static func == (lhs: ServerInfoModel, rhs: ServerInfoModel) -> Bool {
        return lhs.apiBaseUrl == rhs.apiBaseUrl
    }
}
