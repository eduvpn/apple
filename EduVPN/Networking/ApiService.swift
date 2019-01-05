//
//  ApiService.swift
//  EduVPN
//
//  Created by Jeroen Leenarts on 02-08-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

import Foundation

import Moya

import PromiseKit
import AppAuth

enum ApiServiceError: Swift.Error {
    case noAuthState
    case tokenRefreshFailed(rootCause: Error)
}

enum ApiService {
    case profileList
    case userInfo
    case createKeypair(displayName: String)
    case checkCertificate(commonName: String)
    case profileConfig(profileId: String)
    case systemMessages
}

extension ApiService {
    var path: String {
        switch self {
        case .profileList:
            return "/profile_list"
        case .userInfo:
            return "/user_info"
        case .createKeypair:
            return "/create_keypair"
        case .checkCertificate:
            return "/check_certificate"
        case .profileConfig:
            return "/profile_config"
        case .systemMessages:
            return "/system_messages"
        }
    }

    var method: Moya.Method {
        switch self {
        case .profileList, .userInfo, .profileConfig, .systemMessages, .checkCertificate:
            return .get
        case .createKeypair:
            return .post
        }
    }

    var task: Task {
        switch self {
        case .profileList, .userInfo, .systemMessages:
            return .requestPlain
        case .createKeypair(let displayName):
            return .requestParameters(parameters: ["display_name": displayName], encoding: URLEncoding.httpBody)
        case .checkCertificate(let commonName):
            return .requestParameters(parameters: ["common_name": commonName], encoding: URLEncoding.queryString)
        case .profileConfig(let profileId):
            return .requestParameters(parameters: ["profile_id": profileId], encoding: URLEncoding.queryString)
        }
    }

    var sampleData: Data {
        return "".data(using: String.Encoding.utf8)!
    }
}

struct DynamicApiService: TargetType, AcceptJson {
    let baseURL: URL
    let apiService: ApiService

    var path: String { return apiService.path }
    var method: Moya.Method { return apiService.method }
    var task: Task { return apiService.task }
    var sampleData: Data { return apiService.sampleData }
}

class DynamicApiProvider: MoyaProvider<DynamicApiService> {
    let api: Api
    let authConfig: OIDServiceConfiguration
    private var credentialStorePlugin: CredentialStorePlugin

    var actualApi: Api {
        return api.instance?.group?.distributedAuthorizationApi ?? api
    }

    var currentAuthorizationFlow: OIDExternalUserAgentSession?

    public func authorize(presentingViewController: UIViewController) -> Promise<OIDAuthState> {
        let redirectUrl: URL
        let clientId: String
        if let bundleID = Bundle.main.bundleIdentifier, bundleID.contains("appforce1") {
            redirectUrl = URL(string: "https://ios.app.eduvpn.org/auth/app/redirect/development")!
            clientId = "org.eduvpn.app.ios"
        } else if let bundleID = Bundle.main.bundleIdentifier, bundleID.contains("letsconnect") {
            redirectUrl = URL(string: "https://ios.app.letsconnect-vpn.org/auth/app/redirect")!
            clientId = "org.letsconnect-vpn.app.ios"
        } else {
            redirectUrl = URL(string: "https://ios.app.eduvpn.org/auth/app/redirect")!
            clientId = "org.eduvpn.app.ios"
        }

        let request = OIDAuthorizationRequest(configuration: authConfig, clientId: clientId, scopes: ["config"], redirectURL: redirectUrl, responseType: OIDResponseTypeCode, additionalParameters: nil)
        return Promise(resolver: { seal in
            currentAuthorizationFlow = OIDAuthState.authState(byPresenting: request, presenting: presentingViewController, callback: { (authState, error) in

                if let error = error {
                    seal.reject(error)
                    return
                }

                self.actualApi.authState = authState

                precondition(authState != nil, "THIS SHOULD NEVER HAPPEN")

                self.api.managedObjectContext?.perform {
                    self.api.instance?.group?.distributedAuthorizationApi = self.actualApi
                }
                do {
                    try self.api.managedObjectContext?.save()
                } catch {
                    seal.reject(error)
                    return
                }

                seal.fulfill(authState!)
            })
        })
    }

    public init?(api: Api, endpointClosure: @escaping EndpointClosure = MoyaProvider.defaultEndpointMapping,
                 stubClosure: @escaping StubClosure = MoyaProvider.neverStub,
                 callbackQueue: DispatchQueue? = nil,
                 manager: Manager = MoyaProvider<Target>.defaultAlamofireManager(),
                 plugins: [PluginType] = [],
                 trackInflights: Bool = false) {
//    public init(api: Api, endpointClosure: @escaping EndpointClosure = MoyaProvider.defaultEndpointMapping,
//                requestClosure: @escaping RequestClosure = MoyaProvider.defaultRequestMapping,
//                stubClosure: @escaping StubClosure = MoyaProvider.neverStub,
//                manager: Manager = MoyaProvider<DynamicInstanceService>.defaultAlamofireManager(),
//                plugins: [PluginType] = [],
//                trackInflights: Bool = false) {
        guard let authorizationEndpoint = api.authorizationEndpoint else { return nil }
        guard let tokenEndpoint = api.tokenEndpoint else { return nil }
        self.api = api
        self.credentialStorePlugin = CredentialStorePlugin()

        var plugins = plugins
        plugins.append(self.credentialStorePlugin)

        self.authConfig = OIDServiceConfiguration(authorizationEndpoint: URL(string: authorizationEndpoint)!, tokenEndpoint: URL(string: tokenEndpoint)!)
        super.init(endpointClosure: endpointClosure, stubClosure: stubClosure, manager: manager, plugins: plugins, trackInflights: trackInflights)

    }

    public func request(apiService: ApiService,
                        queue: DispatchQueue? = nil,
                        progress: Moya.ProgressBlock? = nil) -> Promise<Moya.Response> {
        return Promise<Void>(resolver: { seal in
            if let authState = self.actualApi.authState {
                authState.performAction(freshTokens: { (accessToken, _, error) in
                    if let error = error {
                        seal.reject(ApiServiceError.tokenRefreshFailed(rootCause: error))
                        return
                    }

                    self.credentialStorePlugin.accessToken = accessToken
                    seal.fulfill(())
                })
            } else {
                seal.reject(ApiServiceError.noAuthState)
            }

        }).then {_ -> Promise<Moya.Response> in
            return self.request(target: DynamicApiService(baseURL: URL(string: self.api.apiBaseUri!)!, apiService: apiService))
        }
    }
}

extension DynamicApiProvider: Hashable {
    static func == (lhs: DynamicApiProvider, rhs: DynamicApiProvider) -> Bool {
        return lhs.api.apiBaseUri == rhs.api.apiBaseUri
    }

    var hashValue: Int {
        return api.apiBaseUri?.hashValue ?? 0
    }
}
