//
//  ApiService.swift
//  eduVPN
//
//  Created by Jeroen Leenarts on 02-08-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

import AppAuth
import Foundation
import Moya
import PromiseKit

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

    var sampleData: Data { return "".data(using: String.Encoding.utf8)! }
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
    
    #if os(macOS)
    // Store it in object strongly, so redirect doesn't fail
    private let redirectHttpHandler = OIDRedirectHTTPHandler(successURL: nil)
    #endif
    
    let api: Api
    let authConfig: OIDServiceConfiguration
    private var credentialStorePlugin: CredentialStorePlugin

    var actualApi: Api { return api.instance?.group?.distributedAuthorizationApi ?? api }

    var currentAuthorizationFlow: OIDExternalUserAgentSession?

    // MARK: - Authorization
    
    private func makeAuthorizeRequest() -> OIDAuthorizationRequest {
        #if os(iOS)
        
        let redirectUrl = Config.shared.redirectUrl
        
        #elseif os(macOS)
        
        var redirectUrl: URL!
        if Thread.isMainThread {
            redirectUrl = redirectHttpHandler.startHTTPListener(nil)
        } else {
            DispatchQueue.main.sync {
                redirectUrl = redirectHttpHandler.startHTTPListener(nil)
            }
        }
        
        redirectUrl = URL(string: "callback", relativeTo: redirectUrl)
        
        #endif
        
        return OIDAuthorizationRequest(configuration: authConfig,
                                       clientId: Config.shared.clientId,
                                       scopes: ["config"],
                                       redirectURL: redirectUrl,
                                       responseType: OIDResponseTypeCode,
                                       additionalParameters: nil)
    }
    
    private func makeAuthorizeCallback(_ seal: Resolver<OIDAuthState>) -> OIDAuthStateAuthorizationCallback {
        return { (authState, error) in
            
            if let error = error {
                seal.reject(error)
                return
            }
            
            self.actualApi.authState = authState
            
            precondition(authState != nil, "THIS SHOULD NEVER HAPPEN")
            
            self.api.managedObjectContext?.performAndWait {
                self.api.instance?.group?.distributedAuthorizationApi = self.actualApi
            }
            
            do {
                try self.api.managedObjectContext?.save()
            } catch {
                seal.reject(error)
                return
            }
            
            seal.fulfill(authState!)
        }
    }
    
    #if os(iOS)
    
    public func authorize(presentingViewController: UIViewController) -> Promise<OIDAuthState> {
        return Promise(resolver: { seal in
            currentAuthorizationFlow = OIDAuthState.authState(byPresenting: self.makeAuthorizeRequest(),
                                                              presenting: presentingViewController,
                                                              callback: self.makeAuthorizeCallback(seal))
        })
    }
    
    #elseif os(macOS)
    
    public func authorize() -> Promise<OIDAuthState> {
        return Promise(resolver: { seal in
            currentAuthorizationFlow = OIDAuthState.authState(byPresenting: self.makeAuthorizeRequest(),
                                                              callback: self.makeAuthorizeCallback(seal))
            redirectHttpHandler.currentAuthorizationFlow = currentAuthorizationFlow
        })
    }
    
    #endif
    
    // MARK: - Constructor

    public init?(api: Api,
                 endpointClosure: @escaping EndpointClosure = MoyaProvider.defaultEndpointMapping,
                 stubClosure: @escaping StubClosure = MoyaProvider.neverStub,
                 callbackQueue: DispatchQueue? = nil,
                 manager: Manager = MoyaProvider<Target>.defaultAlamofireManager(),
                 plugins: [PluginType] = [],
                 trackInflights: Bool = false) {
        
        guard let authorizationEndpoint = api.authorizationEndpoint else { return nil }
        guard let tokenEndpoint = api.tokenEndpoint else { return nil }
        
        self.api = api
        self.credentialStorePlugin = CredentialStorePlugin()

        var plugins = plugins
        plugins.append(self.credentialStorePlugin)

        self.authConfig = OIDServiceConfiguration(authorizationEndpoint: URL(string: authorizationEndpoint)!,
                                                  tokenEndpoint: URL(string: tokenEndpoint)!)
        
        super.init(endpointClosure: endpointClosure,
                   stubClosure: stubClosure,
                   manager: manager,
                   plugins: plugins,
                   trackInflights: trackInflights)
    }

    public func request(apiService: ApiService,
                        queue: DispatchQueue? = nil,
                        progress: Moya.ProgressBlock? = nil) -> Promise<Moya.Response> {
        
        return Promise<Void>(resolver: { seal in
            if let authState = self.actualApi.authState {
                authState.performAction { (accessToken, _, error) in
                    if let error = error {
                        if (error as NSError).code == OIDErrorCode.networkError.rawValue {
                            seal.reject(error)
                        } else {
                            seal.reject(ApiServiceError.tokenRefreshFailed(rootCause: error))
                        }
                        return
                    }

                    self.credentialStorePlugin.accessToken = accessToken
                    seal.fulfill(())
                }
            } else {
                seal.reject(ApiServiceError.noAuthState)
            }

        }).then {_ -> Promise<Moya.Response> in
            self.request(target: DynamicApiService(baseURL: URL(string: self.api.apiBaseUri!)!, apiService: apiService))
        }
    }
}

extension DynamicApiProvider: Hashable {
    
    static func == (lhs: DynamicApiProvider, rhs: DynamicApiProvider) -> Bool {
        return lhs.api.apiBaseUri == rhs.api.apiBaseUri
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(api.apiBaseUri)
    }
}
