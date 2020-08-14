//
//  ServerInfoFetcher.swift
//  EduVPN
//
//  Fetches info.json from a server base URL
//

import Foundation
import Moya
import PromiseKit

struct ServerInfoFetcher {

    struct ServerInfoTarget: TargetType, AcceptJson, SimpleGettable {
        var baseURL: URL
        var path: String { "/info.json" }

        init(_ url: URL) {
            baseURL = url
        }
    }

    static var uncachedSession: Moya.Session {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = nil
        return Session(configuration: configuration, startRequestsImmediately: false)
    }

    static func fetch(baseURLString: DiscoveryData.BaseURLString) -> Promise<ServerInfo> {
        let provider = MoyaProvider<ServerInfoTarget>(session: Self.uncachedSession)
        return firstly {
            provider.request(target: ServerInfoTarget(try baseURLString.toURL()))
        }.map { response in
            try JSONDecoder().decode(ServerInfo.self, from: response.data)
        }
    }

    static func fetch(apiBaseURLString: DiscoveryData.BaseURLString,
                      authBaseURLString: DiscoveryData.BaseURLString) -> Promise<ServerInfo> {
        guard apiBaseURLString != authBaseURLString else {
            return fetch(baseURLString: authBaseURLString)
        }
        return firstly { () -> Promise<[Moya.Response]> in
            let apiBaseURL = try apiBaseURLString.toURL()
            let authBaseURL = try authBaseURLString.toURL()

            let provider = MoyaProvider<ServerInfoTarget>(session: Self.uncachedSession)
            let apiServerInfoPromise = provider.request(target: ServerInfoTarget(apiBaseURL))
            let authServerInfoPromise = provider.request(target: ServerInfoTarget(authBaseURL))

            return when(fulfilled: [apiServerInfoPromise, authServerInfoPromise])
        }.map { responses in
            precondition(responses.count == 2)
            let serverInfos = try responses.map { try JSONDecoder().decode(ServerInfo.self, from: $0.data) }
            let apiServerInfo = serverInfos[0]
            let authServerInfo = serverInfos[1]
            return ServerInfo(
                authorizationEndpoint: authServerInfo.authorizationEndpoint,
                tokenEndpoint: authServerInfo.tokenEndpoint,
                apiBaseURL: apiServerInfo.apiBaseURL)
        }
    }
}
