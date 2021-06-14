//
//  ServerInfo.swift
//  eduVPN
//

// Models the data extracted from <server_base_url>/info.json

import Foundation

struct ServerInfo: Decodable {

    typealias BaseURL = URL
    typealias OAuthEndpoint = URL

    enum APIVersion: String {
        case apiv2
        case apiv3
    }

    var apiVersion: APIVersion
    var authorizationEndpoint: OAuthEndpoint
    var tokenEndpoint: OAuthEndpoint
    var apiBaseURL: BaseURL
}

extension ServerInfo {

    enum ServerInfoKeys: String, CodingKey {
        case api
        case apiv2 = "http://eduvpn.org/api#2"
        case apiv3 = "http://eduvpn.org/api#3"
        case authorizationEndpoint = "authorization_endpoint"
        case tokenEndpoint = "token_endpoint"
        case apiBaseURL = "api_base_uri" // Only in APIv2
        case apiEndpoint = "api_endpoint" // Only in APIv3
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: ServerInfoKeys.self)
        let apiContainer = try container.nestedContainer(keyedBy: ServerInfoKeys.self, forKey: .api)

        if let apiv3Container = try? apiContainer.nestedContainer(keyedBy: ServerInfoKeys.self, forKey: .apiv3) {
            let authorizationEndpoint = try apiv3Container.decode(URL.self, forKey: .authorizationEndpoint)
            let tokenEndpoint = try apiv3Container.decode(URL.self, forKey: .tokenEndpoint)
            let apiBaseURL = try apiv3Container.decode(URL.self, forKey: .apiEndpoint)

            self.init(
                apiVersion: .apiv3,
                authorizationEndpoint: authorizationEndpoint,
                tokenEndpoint: tokenEndpoint,
                apiBaseURL: apiBaseURL)
        } else {
            let apiv2Container = try apiContainer.nestedContainer(keyedBy: ServerInfoKeys.self, forKey: .apiv2)
            let authorizationEndpoint = try apiv2Container.decode(URL.self, forKey: .authorizationEndpoint)
            let tokenEndpoint = try apiv2Container.decode(URL.self, forKey: .tokenEndpoint)
            let apiBaseURL = try apiv2Container.decode(URL.self, forKey: .apiBaseURL)

            self.init(
                apiVersion: .apiv2,
                authorizationEndpoint: authorizationEndpoint,
                tokenEndpoint: tokenEndpoint,
                apiBaseURL: apiBaseURL)
        }
    }
}
