//
//  ServerAuthService.swift
//  EduVPN-redesign-macOS
//

import Foundation
import AppAuth
import Moya
import PromiseKit

class ServerAuthService {
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

    private let configRedirectURL: URL // For iOS
    private let configClientId: String // For macOS

    private var currentAuthFlow: OIDExternalUserAgentSession?

    #if os(macOS)
    private lazy var redirectHttpHandler = OIDRedirectHTTPHandler(successURL: nil)
    #endif

    var redirectURL: URL {
        #if os(macOS)
        assert(Thread.isMainThread)
        return URL(
            string: "callback",
            relativeTo: redirectHttpHandler.startHTTPListener(nil))! // swiftlint:disable:this force_unwrapping
        #elseif os(iOS)
        return configRedirectURL
        #endif
    }

    init(configRedirectURL: URL, configClientId: String) {
        self.configRedirectURL = configRedirectURL
        self.configClientId = configClientId
    }

    func startAuth(baseURLString: DiscoveryData.BaseURLString,
                   from viewController: ViewController) -> Promise<AuthState> {
        return firstly {
            ServerInfoFetcher.fetch(baseURLString: baseURLString)
        }.then { serverInfo in
            self.startAuth(
                authEndpoint: serverInfo.authorizationEndpoint,
                tokenEndpoint: serverInfo.tokenEndpoint,
                from: viewController)
        }
    }

    func startAuth(authEndpoint: URL, tokenEndpoint: URL,
                   from viewController: ViewController) -> Promise<AuthState> {
        let authConfig = OIDServiceConfiguration(
            authorizationEndpoint: authEndpoint,
            tokenEndpoint: tokenEndpoint)
        let authRequest = OIDAuthorizationRequest(
            configuration: authConfig,
            clientId: configClientId,
            scopes: ["config"],
            redirectURL: redirectURL,
            responseType: OIDResponseTypeCode,
            additionalParameters: nil)
        return Promise { seal in
            let authFlow = Self.createAuthState(
                authRequest: authRequest,
                presentingViewController: viewController) { (authState, error) in
                    if let authState = authState {
                        seal.resolve(AuthState(oidAuthState: authState), error)
                    } else {
                        seal.resolve(nil, error)
                    }
            }
            #if os(macOS)
            redirectHttpHandler.currentAuthorizationFlow = authFlow
            #endif
            currentAuthFlow = authFlow
        }
    }

    #if os(iOS)
    @discardableResult
    func resumeAuth(with url: URL) -> Bool {
        guard let currentAuthFlow = currentAuthFlow else {
            return false
        }
        return currentAuthFlow.resumeExternalUserAgentFlow(with: url)
    }
    #endif

    func cancelAuth() {
        #if os(macOS)
        redirectHttpHandler.cancelHTTPListener()
        #endif
        if let currentAuthFlow = currentAuthFlow {
            currentAuthFlow.cancel()
        }
    }

    func isUserCancelledError(_ error: Error) -> Bool {
        let domain = (error as NSError).domain
        let code = (error as NSError).code
        return domain == OIDGeneralErrorDomain &&
            (code == OIDErrorCode.programCanceledAuthorizationFlow.rawValue ||
                code == OIDErrorCode.userCanceledAuthorizationFlow.rawValue)
    }

    private static func createAuthState(
        authRequest: OIDAuthorizationRequest,
        presentingViewController: ViewController,
        callback: @escaping OIDAuthStateAuthorizationCallback) -> OIDExternalUserAgentSession? {

        #if os(macOS)
        return OIDAuthState.authState(byPresenting: authRequest,
                                      callback: callback)
        #elseif os(iOS)
        return OIDAuthState.authState(byPresenting: authRequest,
                                      presentingViewController: presentingViewController,
                                      callback: callback)
        #endif
    }
}
