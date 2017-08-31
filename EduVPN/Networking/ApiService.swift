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
}

enum ApiService {
    case profileList
    case userInfo
    case createConfig(displayName: String, profileId: String)
    case createKeypair(displayName: String)
    case profileConfig(profileId: String)
    case systemMessages
    case userMessages
}

extension ApiService {
    var path: String {
        switch self {
        case .profileList:
            return "/profile_list"
        case .userInfo:
            return "/user_info"
        case .createConfig:
            return "/create_config"
        case .createKeypair:
            return "/create_keypair"
        case .profileConfig:
            return "/profile_config"
        case .systemMessages:
            return "/system_messages"
        case .userMessages:
            return "/user_messages"
        }
    }

    var method: Moya.Method {
        switch self {
        case .profileList, .userInfo, .profileConfig, .systemMessages, .userMessages:
            return .get
        case .createConfig, .createKeypair:
            return .post
        }
    }

    var parameters: [String: Any]? {
        switch self {
        case .profileList, .userInfo, .systemMessages, .userMessages:
            return nil
        case .createConfig(let displayName, let profileId):
            return ["display_name": displayName, "profile_id": profileId]
        case .createKeypair(let displayName):
            return ["display_name": displayName]
        case .profileConfig(let profileId):
            return ["profile_id": profileId]
        }
    }

    var parameterEncoding: ParameterEncoding {
        return URLEncoding.default // Send parameters in URL for GET, DELETE and HEAD. For other HTTP methods, parameters will be sent in request body
    }

    var task: Task {
        return .request
    }

    var sampleData: Data {
        return "".data(using: String.Encoding.utf8)!
    }
}

struct DynamicApiService: TargetType {
    let baseURL: URL
    let apiService: ApiService

    var path: String { return apiService.path }
    var method: Moya.Method { return apiService.method }
    var parameters: [String: Any]? { return apiService.parameters }
    var parameterEncoding: ParameterEncoding { return apiService.parameterEncoding }
    var task: Task { return apiService.task }
    var sampleData: Data { return apiService.sampleData }
}

class DynamicApiProvider: MoyaProvider<DynamicApiService> {
    let instanceInfo: InstanceInfoModel
    let authConfig: OIDServiceConfiguration
    private var credentialStorePlugin: CredentialStorePlugin

    var authState: OIDAuthState?

    var currentAuthorizationFlow: OIDAuthorizationFlowSession?

    public func authorize(presentingViewController: UIViewController) -> Promise<OIDAuthState> {
        let request = OIDAuthorizationRequest(configuration: authConfig, clientId: "org.eduvpn.app", scopes: [OIDScopeOpenID, OIDScopeProfile], redirectURL: URL(string: "org.eduvpn.app:/api/callback")!, responseType: OIDResponseTypeCode, additionalParameters: nil)
        return Promise(resolvers: { fulfill, reject in
            currentAuthorizationFlow = OIDAuthState.authState(byPresenting: request, presenting: presentingViewController, callback: { (authState, error) in

                if let error = error {
                    print("Authorization error \(error.localizedDescription)")
                    reject(error)
                    return
                }

                self.authState = authState

                precondition(authState != nil, "THIS SHOULD NEVER HAPPEN")

                //TODO: Use CredentialStorePlugin
                print("Got authorization tokens. Access token: \(String(describing: authState!.lastTokenResponse?.accessToken))")
                fulfill(authState!)

            })
        })
    }

    public init(instanceInfo: InstanceInfoModel, endpointClosure: @escaping EndpointClosure = MoyaProvider.defaultEndpointMapping,
                requestClosure: @escaping RequestClosure = MoyaProvider.defaultRequestMapping,
                stubClosure: @escaping StubClosure = MoyaProvider.neverStub,
                manager: Manager = MoyaProvider<DynamicInstanceService>.defaultAlamofireManager(),
                plugins: [PluginType] = [],
                trackInflights: Bool = false) {
        self.instanceInfo = instanceInfo
        self.credentialStorePlugin = CredentialStorePlugin()

        var plugins = plugins
        plugins.append(self.credentialStorePlugin)

        self.authConfig = OIDServiceConfiguration(authorizationEndpoint: instanceInfo.authorizationEndpoint, tokenEndpoint: instanceInfo.tokenEndpoint)
        super.init(endpointClosure: endpointClosure, requestClosure: requestClosure, stubClosure: stubClosure, manager: manager, plugins: plugins, trackInflights: trackInflights)

    }

    public func request(target: ApiService,
                        queue: DispatchQueue? = nil,
                        progress: Moya.ProgressBlock? = nil) -> Promise<Moya.Response> {
        return Promise(resolvers: { fulfill, reject in
            if let authState = self.authState {
                authState.performAction(freshTokens: { (accessToken, _, error) in
                    if let error = error {
                        reject(error)
                        return
                    }

                    self.credentialStorePlugin.accessToken = accessToken
                    fulfill(())
                })
            } else {
                reject(ApiServiceError.noAuthState)
            }

        }).then {
            return self.request(target: DynamicApiService(baseURL: self.instanceInfo.apiBaseUrl, apiService: target))
        }
    }
}

extension DynamicApiProvider: Hashable {
    static func == (lhs: DynamicApiProvider, rhs: DynamicApiProvider) -> Bool {
        return lhs.instanceInfo.apiBaseUrl == rhs.instanceInfo.apiBaseUrl
    }

    var hashValue: Int {
        return instanceInfo.apiBaseUrl.hashValue
    }
}
