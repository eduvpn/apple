//
//  ServerInfoFetcher.swift
//  EduVPN
//
//  Fetches info.json from a server base URL
//

import Foundation
import Moya
import PromiseKit

enum ServerInfoFetcherError: Error {
    case apiVersionMismatch(
          authServer: (urlString: DiscoveryData.BaseURLString, apiVersion: ServerInfo.APIVersion),
          apiServer: (urlString: DiscoveryData.BaseURLString, apiVersion: ServerInfo.APIVersion))
}

extension ServerInfoFetcherError: AppError {
    var summary: String {
        switch self {
        case .apiVersionMismatch:
            return "Authentication server and API server have different API versions"
        }
    }
    var detail: String {
        switch self {
        case .apiVersionMismatch(let authServer, let apiServer):
            return """
                Authentication server:
                    URL: \(authServer.urlString.urlString)
                    API version: \(authServer.apiVersion)
                API server:
                    URL: \(apiServer.urlString.urlString)
                    API version: \(apiServer.apiVersion)
                """
        }
    }
}

class ServerInfoFetcher {

    struct ServerInfoTarget: TargetType, AcceptJson, SimpleGettable {
        var baseURL: URL
        var path: String { ".well-known/vpn-user-portal" } // Previously info.json

        init(_ url: URL) {
            baseURL = url
        }
    }

    let uncachedSession: Moya.Session = {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = nil
        return Session(configuration: configuration, startRequestsImmediately: false)
    }()

    var inFlightRequests: [Moya.Cancellable] = []

    func fetch(baseURLString: DiscoveryData.BaseURLString) -> Promise<ServerInfo> {
        let provider = MoyaProvider<ServerInfoTarget>(session: self.uncachedSession)
        return firstly { () -> Promise<Moya.Response> in
            let (promise, request) = provider.requestCancellable(target: ServerInfoTarget(try baseURLString.toURL()))
            self.inFlightRequests = [request]
            return promise
        }.map { response in
            try JSONDecoder().decode(ServerInfo.self, from: response.data)
        }.ensure {
            self.inFlightRequests = []
        }
    }

    func fetch(apiBaseURLString: DiscoveryData.BaseURLString,
               authBaseURLString: DiscoveryData.BaseURLString) -> Promise<ServerInfo> {
        guard apiBaseURLString != authBaseURLString else {
            return fetch(baseURLString: authBaseURLString)
        }
        return firstly { () -> Promise<[Moya.Response]> in
            let apiBaseURL = try apiBaseURLString.toURL()
            let authBaseURL = try authBaseURLString.toURL()

            let provider = MoyaProvider<ServerInfoTarget>(session: self.uncachedSession)
            let (apiPromise, apiRequest) = provider.requestCancellable(target: ServerInfoTarget(apiBaseURL))
            let (authPromise, authRequest) = provider.requestCancellable(target: ServerInfoTarget(authBaseURL))
            self.inFlightRequests = [apiRequest, authRequest]

            return when(fulfilled: [apiPromise, authPromise])
        }.map { responses in
            precondition(responses.count == 2)
            let serverInfos = try responses.map { try JSONDecoder().decode(ServerInfo.self, from: $0.data) }
            let apiServerInfo = serverInfos[0]
            let authServerInfo = serverInfos[1]
            guard authServerInfo.apiVersion == apiServerInfo.apiVersion else {
                throw ServerInfoFetcherError.apiVersionMismatch(
                    authServer: (authBaseURLString, authServerInfo.apiVersion),
                    apiServer: (apiBaseURLString, apiServerInfo.apiVersion))
            }
            return ServerInfo(
                apiVersion: apiServerInfo.apiVersion,
                authorizationEndpoint: authServerInfo.authorizationEndpoint,
                tokenEndpoint: authServerInfo.tokenEndpoint,
                apiBaseURL: apiServerInfo.apiBaseURL)
        }.ensure {
            self.inFlightRequests = []
        }
    }

    func cancelFetch() {
        _ = inFlightRequests.map { $0.cancel() }
    }
}
