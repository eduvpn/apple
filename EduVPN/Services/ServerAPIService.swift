//
//  ServerAPIService.swift
//  EduVPN
//

import Foundation
import AppAuth
import Moya
import Alamofire
import PromiseKit
import ASN1Decoder
import os.log

enum ServerAPIServiceError: Error {
    case cannotUseStoredAuthState
    case cannotUseStoredKeyPair // Applies to APIv2 only
    case unauthorized(authorizationError: Error)
}

class ServerAPIService {
    struct Options: OptionSet {
        let rawValue: Int

        static let ignoreStoredAuthState = Options(rawValue: 1 << 0)
        static let ignoreStoredKeyPair = Options(rawValue: 1 << 1) // APIv2 only
    }

    enum VPNConfiguration {
        case openVPNConfig([String])
        case wireGuardConfig(String)
    }

    struct TunnelConfigurationData {
        let vpnConfig: VPNConfiguration
        let expiresAt: Date
        let serverAPIBaseURL: URL
        let serverAPIVersion: ServerInfo.APIVersion
    }

    struct CommonAPIRequestInfo {
        let serverInfo: ServerInfo
        let dataStore: PersistenceService.DataStore
        let session: Moya.Session
        let serverAuthService: ServerAuthService
        let wayfSkippingInfo: ServerAuthService.WAYFSkippingInfo?
        let sourceViewController: AuthorizingViewController
    }

    class OCSPStaplingEnforcedTrustManager: ServerTrustManager {
        init() {
            super.init(allHostsMustBeEvaluated: true, evaluators: [:])
        }
        override func serverTrustEvaluator(forHost host: String) throws -> ServerTrustEvaluating? {
            return RevocationTrustEvaluator(options: [.ocsp, .requirePositiveResponse])
        }
    }

    static var uncachedSession: Moya.Session {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = nil
        return Session(
            configuration: configuration,
            startRequestsImmediately: false,
            serverTrustManager: OCSPStaplingEnforcedTrustManager())
    }

    private let serverAuthService: ServerAuthService
    private var authStateChangeHandler: AuthStateChangeHandler?

    init(serverAuthService: ServerAuthService) {
        self.serverAuthService = serverAuthService
    }

    private static func serverAPIHandlerType(for apiVersion: ServerInfo.APIVersion) -> ServerAPIHandler.Type {
        switch apiVersion {
        case .apiv2:
            return ServerAPIv2Handler.self
        case .apiv3:
            return ServerAPIv3Handler.self
        }
    }

    func getAvailableProfiles(for server: ServerInstance,
                              from viewController: AuthorizingViewController,
                              wayfSkippingInfo: ServerAuthService.WAYFSkippingInfo?,
                              options: Options) -> Promise<([Profile], ServerInfo)> {
        return firstly {
            ServerInfoFetcher.fetch(apiBaseURLString: server.apiBaseURLString,
                                    authBaseURLString: server.authBaseURLString)
        }.then { serverInfo -> Promise<([Profile], ServerInfo)> in
            let dataStore = PersistenceService.DataStore(path: server.localStoragePath)
            let commonInfo = ServerAPIService.CommonAPIRequestInfo(
                serverInfo: serverInfo,
                dataStore: dataStore,
                session: Self.uncachedSession,
                serverAuthService: self.serverAuthService,
                wayfSkippingInfo: wayfSkippingInfo,
                sourceViewController: viewController)
            let serverAPIHandler = Self.serverAPIHandlerType(for: serverInfo.apiVersion)
            return serverAPIHandler.getAvailableProfiles(
                commonInfo: commonInfo,
                options: options)
                .map { ($0, serverInfo) }
        }
    }

    // swiftlint:disable:next function_parameter_count
    func getTunnelConfigurationData(for server: ServerInstance, serverInfo: ServerInfo?,
                                    profile: Profile,
                                    from viewController: AuthorizingViewController,
                                    wayfSkippingInfo: ServerAuthService.WAYFSkippingInfo?,
                                    options: Options) -> Promise<TunnelConfigurationData> {
        return firstly { () -> Promise<ServerInfo> in
            if let serverInfo = serverInfo {
                return Promise.value(serverInfo)
            }
            return ServerInfoFetcher.fetch(apiBaseURLString: server.apiBaseURLString,
                                           authBaseURLString: server.authBaseURLString)
        }.then { serverInfo -> Promise<TunnelConfigurationData> in
            let dataStore = PersistenceService.DataStore(path: server.localStoragePath)
            let commonInfo = ServerAPIService.CommonAPIRequestInfo(
                serverInfo: serverInfo,
                dataStore: dataStore,
                session: Self.uncachedSession,
                serverAuthService: self.serverAuthService,
                wayfSkippingInfo: wayfSkippingInfo,
                sourceViewController: viewController)
            let serverAPIHandler = Self.serverAPIHandlerType(for: serverInfo.apiVersion)
            return serverAPIHandler.getTunnelConfigurationData(
                commonInfo: commonInfo, profile: profile, options: options)
        }
    }

    func attemptToRelinquishTunnelConfiguration(
        apiVersion: ServerInfo.APIVersion,
        baseURL: URL, dataStore: PersistenceService.DataStore,
        profile: Profile, shouldFireAndForget: Bool) -> Promise<Void> {

        let serverAPIHandler = Self.serverAPIHandlerType(for: apiVersion)
        return serverAPIHandler.attemptToRelinquishTunnelConfiguration(
            baseURL: baseURL, dataStore: dataStore,
            session: Self.uncachedSession, profile: profile,
            shouldFireAndForget: shouldFireAndForget)
    }
}

protocol ServerAPIHandler {
    static var authStateChangeHandler: AuthStateChangeHandler? { get set }
    static func getAvailableProfiles(
        commonInfo: ServerAPIService.CommonAPIRequestInfo,
        options: ServerAPIService.Options) -> Promise<[Profile]>
    static func getTunnelConfigurationData(
        commonInfo: ServerAPIService.CommonAPIRequestInfo,
        profile: Profile,
        options: ServerAPIService.Options) -> Promise<ServerAPIService.TunnelConfigurationData>
    static func attemptToRelinquishTunnelConfiguration(
        baseURL: URL, dataStore: PersistenceService.DataStore, session: Moya.Session,
        profile: Profile, shouldFireAndForget: Bool) -> Promise<Void>
}

extension ServerAPIHandler {
    static func getFreshAccessToken(
        commonInfo: ServerAPIService.CommonAPIRequestInfo,
        options: ServerAPIService.Options) -> Promise<String> {

        return firstly { () -> Promise<String> in
            if options.contains(.ignoreStoredAuthState) {
                throw ServerAPIServiceError.cannotUseStoredAuthState
            }
            guard let authState = commonInfo.dataStore.authState else {
                throw ServerAPIServiceError.cannotUseStoredAuthState
            }
            return self.getFreshAccessToken(using: authState, storingChangesTo: commonInfo.dataStore)
        }.recover { error -> Promise<String> in
            os_log("Error getting access token: %{public}@", log: Log.general, type: .error,
                   error.localizedDescription)
            switch error {
            case ServerAPIServiceError.cannotUseStoredAuthState,
                 ServerAPIServiceError.unauthorized:
                os_log("Starting fresh authentication", log: Log.general, type: .info)
                return commonInfo.serverAuthService.startAuth(
                    authEndpoint: commonInfo.serverInfo.authorizationEndpoint,
                    tokenEndpoint: commonInfo.serverInfo.tokenEndpoint,
                    from: commonInfo.sourceViewController,
                    wayfSkippingInfo: commonInfo.wayfSkippingInfo)
                .then { authState -> Promise<String> in
                    commonInfo.dataStore.authState = authState
                    return self.getFreshAccessToken(using: authState, storingChangesTo: commonInfo.dataStore)
                }
            default:
                throw error
            }
        }
    }

    static func getFreshAccessToken(
        using authState: AuthState,
        storingChangesTo dataStore: PersistenceService.DataStore) -> Promise<String> {

        return Promise { seal in
            let authStateChangeHandler = AuthStateChangeHandler(dataStore: dataStore)
            authState.oidAuthState.stateChangeDelegate = authStateChangeHandler
            Self.authStateChangeHandler = authStateChangeHandler
            authState.oidAuthState.performAction { (accessToken, _, error) in
                authState.oidAuthState.stateChangeDelegate = nil
                Self.authStateChangeHandler = nil
                if let authorizationError = authState.oidAuthState.authorizationError {
                    let error = ServerAPIServiceError.unauthorized(
                        authorizationError: authorizationError)
                    seal.reject(error)
                } else {
                    seal.resolve(accessToken, error)
                }
            }
        }
    }
}

class AuthStateChangeHandler: NSObject, OIDAuthStateChangeDelegate {
    let dataStore: PersistenceService.DataStore

    init(dataStore: PersistenceService.DataStore) {
        self.dataStore = dataStore
    }

    func didChange(_ state: OIDAuthState) {
        dataStore.authState = AuthState(oidAuthState: state)
    }
}
