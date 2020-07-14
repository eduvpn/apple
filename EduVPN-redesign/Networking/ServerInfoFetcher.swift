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
            try Self.parseServerInfo(response.data)
        }
    }

    private static func parseServerInfo(_ data: Data) throws -> ServerInfo {
        return try JSONDecoder().decode(ServerInfo.self, from: data)
    }
}
