//
//  ServerAPIService.swift
//  EduVPN
//

import Foundation
import AppAuth
import Moya
import PromiseKit
import ASN1Decoder
import os.log

enum ServerAPIServiceError: Error {
    case serverProvidedInvalidCertificate
    case HTTPFailure(requestURLPath: String, response: Moya.Response)
    case errorGettingProfileConfig(profile: ProfileListResponse.Profile, serverError: String)
}

class ServerAPIService {

    struct Options: OptionSet {
        let rawValue: Int

        static let ignoreStoredAuthState = Options(rawValue: 1 << 0)
        static let ignoreStoredKeyPair = Options(rawValue: 1 << 1)
    }

    struct TunnelConfigurationData {
        let openVPNConfiguration: [String]
        let certificateExpiresAt: Date
    }

    static var uncachedSession: Moya.Session {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = nil
        return Session(configuration: configuration, startRequestsImmediately: false)
    }

    private let serverAuthService: ServerAuthService

    init(serverAuthService: ServerAuthService) {
        self.serverAuthService = serverAuthService
    }

    func getAvailableProfiles(for server: ServerInstance,
                              from viewController: AuthorizingViewController,
                              options: Options = []) -> Promise<([ProfileListResponse.Profile], ServerInfo)> {
        return firstly {
            ServerInfoFetcher.fetch(apiBaseURLString: server.apiBaseURLString,
                                    authBaseURLString: server.authBaseURLString)
        }.then { serverInfo -> Promise<([ProfileListResponse.Profile], ServerInfo)> in
            let dataStore = PersistenceService.DataStore(path: server.localStoragePath)
            let basicTargetInfo = BasicTargetInfo(serverInfo: serverInfo,
                                                  dataStore: dataStore,
                                                  sourceViewController: viewController)
            return self.makeRequest(target: .profileList(basicTargetInfo),
                                    decodeAs: ProfileListResponse.self,
                                    options: options)
                .map { ($0, serverInfo) }
        }
    }

    func getTunnelConfigurationData(for server: ServerInstance,
                                    profile: ProfileListResponse.Profile,
                                    from viewController: AuthorizingViewController,
                                    options: Options = []) -> Promise<TunnelConfigurationData> {
        return firstly {
            ServerInfoFetcher.fetch(apiBaseURLString: server.apiBaseURLString,
                                    authBaseURLString: server.authBaseURLString)
        }.then { serverInfo -> Promise<TunnelConfigurationData> in
            return self.getTunnelConfigurationData(for: server, serverInfo: serverInfo, profile: profile,
                                              from: viewController, options: options)
        }
    }

    func getTunnelConfigurationData(for server: ServerInstance, serverInfo: ServerInfo,
                                    profile: ProfileListResponse.Profile,
                                    from viewController: AuthorizingViewController,
                                    options: Options = []) -> Promise<TunnelConfigurationData> {
        let dataStore = PersistenceService.DataStore(path: server.localStoragePath)
        let basicTargetInfo = BasicTargetInfo(serverInfo: serverInfo,
                                              dataStore: dataStore,
                                              sourceViewController: viewController)
        return firstly {
            getKeyPair(basicTargetInfo: basicTargetInfo, options: options)
        }.then { (keyPair, expiryDate) in
            self.getProfileConfig(basicTargetInfo: basicTargetInfo, profile: profile, options: options)
                .map { profileConfig in
                    let openVPNConfig = Self.createOpenVPNConfig(
                        profileConfig: profileConfig, isUDPAllowed: true, keyPair: keyPair)
                    return TunnelConfigurationData(openVPNConfiguration: openVPNConfig, certificateExpiresAt: expiryDate)
                }
        }
    }

}

private extension ServerAPIService {

    enum StoredDataError: Error {
        case cannotUseStoredAuthState
        case cannotUseStoredKeyPair
    }

    struct BasicTargetInfo {
        let serverInfo: ServerInfo
        let dataStore: PersistenceService.DataStore
        let sourceViewController: AuthorizingViewController
    }

    enum ServerAPITarget: TargetType, AcceptJson, AccessTokenAuthorizable {
        case profileList(BasicTargetInfo)
        case createKeyPair(BasicTargetInfo, displayName: String)
        case checkCertificate(BasicTargetInfo, commonName: String)
        case profileConfig(BasicTargetInfo, profile: ProfileListResponse.Profile)

        var basicTargetInfo: BasicTargetInfo {
            switch self {
            case .profileList(let basicTargetInfo): return basicTargetInfo
            case .createKeyPair(let basicTargetInfo, _): return basicTargetInfo
            case .checkCertificate(let basicTargetInfo, _): return basicTargetInfo
            case .profileConfig(let basicTargetInfo, _): return basicTargetInfo
            }
        }

        var baseURL: URL { basicTargetInfo.serverInfo.apiBaseURL }

        var path: String {
            switch self {
            case .profileList: return "/profile_list"
            case .createKeyPair: return "/create_keypair"
            case .checkCertificate: return "/check_certificate"
            case .profileConfig: return "/profile_config"
            }
        }

        var method: Moya.Method {
            switch self {
            case .profileList, .checkCertificate, .profileConfig: return .get
            case .createKeyPair: return .post
            }
        }

        var sampleData: Data { Data() }

        var task: Task {
            switch self {
            case .profileList:
                return .requestPlain
            case .createKeyPair(_, let displayName):
                return .requestParameters(
                    parameters: ["display_name": displayName],
                    encoding: URLEncoding.httpBody)
            case .checkCertificate(_, let commonName):
                return .requestParameters(
                    parameters: ["common_name": commonName],
                    encoding: URLEncoding.queryString)
            case .profileConfig(_, let profile):
                return .requestParameters(
                    parameters: ["profile_id": profile.profileId],
                    encoding: URLEncoding.queryString)
            }
        }

        var authorizationType: AuthorizationType? { .bearer }
    }

    static let HTTPStatusCodeUnauthorized = 401

    func makeRequest<T: ServerResponse>(target: ServerAPITarget, decodeAs responseType: T.Type,
                                        options: Options) -> Promise<T.DataType> {
        firstly { () -> Promise<String> in
            self.getFreshAccessToken(basicTargetInfo: target.basicTargetInfo)
        }.then { accessToken -> Promise<Moya.Response> in
            let authPlugin = AccessTokenPlugin { _ in accessToken }
            let provider = MoyaProvider<ServerAPITarget>(session: Self.uncachedSession, plugins: [authPlugin])
            return provider.request(target: target)
        }.then { response -> Promise<T.DataType> in
            if response.statusCode == Self.HTTPStatusCodeUnauthorized &&
                !options.contains(.ignoreStoredAuthState) {
                os_log("Encountered HTTP status code Unauthorized", log: Log.general, type: .info)
                return self.makeRequest(target: target, decodeAs: responseType,
                                        options: options.union([.ignoreStoredAuthState]))
            } else {
                let successStatusCodes = (200...299)
                guard successStatusCodes.contains(response.statusCode) else {
                    throw ServerAPIServiceError.HTTPFailure(requestURLPath: target.path, response: response)
                }
                return Promise.value(try T(data: response.data).data)
            }
        }
    }

    func getKeyPair(basicTargetInfo: BasicTargetInfo,
                    options: Options = []) -> Promise<(CreateKeyPairResponse.KeyPair, Date)> {
        firstly { () -> Promise<(CreateKeyPairResponse.KeyPair, Date)> in
            guard !options.contains(.ignoreStoredKeyPair),
                let storedKeyPair = basicTargetInfo.dataStore.keyPair,
                let certificateData = storedKeyPair.certificate.data(using: .utf8),
                let x509Certificate = try? X509Certificate(data: certificateData),
                x509Certificate.isCurrentlyValid,
                let commonName = x509Certificate.commonName,
                let expiresAt = x509Certificate.expiresAt else {
                    throw StoredDataError.cannotUseStoredKeyPair
            }
            return makeRequest(
                target: .checkCertificate(basicTargetInfo, commonName: commonName),
                decodeAs: CheckCertificateResponse.self, options: options)
                .map { certificateValidity in
                    guard certificateValidity.isValid else {
                        throw StoredDataError.cannotUseStoredKeyPair
                    }
                    return (storedKeyPair, expiresAt)
                }
        }.recover { error -> Promise<(CreateKeyPairResponse.KeyPair, Date)> in
            if case StoredDataError.cannotUseStoredKeyPair = error {
                return self.makeRequest(
                    target: .createKeyPair(basicTargetInfo, displayName: Config.shared.appName),
                    decodeAs: CreateKeyPairResponse.self, options: options)
                    .map { keyPair in
                        basicTargetInfo.dataStore.keyPair = keyPair
                        guard let certificateData = keyPair.certificate.data(using: .utf8),
                            let x509Certificate = try? X509Certificate(data: certificateData),
                            x509Certificate.isCurrentlyValid,
                            let expiresAt = x509Certificate.expiresAt else {
                                throw ServerAPIServiceError.serverProvidedInvalidCertificate
                        }
                        return (keyPair, expiresAt)
                    }
            } else {
                throw error
            }
        }
    }

    func getProfileConfig(basicTargetInfo: BasicTargetInfo, profile: ProfileListResponse.Profile,
                          options: Options = []) -> Promise<Data> {
        firstly {
            makeRequest(target: .profileConfig(basicTargetInfo, profile: profile),
                        decodeAs: ProfileConfigResponse.self, options: options)
        }.map { data in
            if let errorResponse = try? JSONDecoder().decode(ProfileConfigErrorResponse.self, from: data) {
                throw ServerAPIServiceError.errorGettingProfileConfig(profile: profile, serverError: errorResponse.errorMessage)
            }
            return data
        }
    }

    static func createOpenVPNConfig(
        profileConfig profileConfigData: Data,
        isUDPAllowed: Bool,
        keyPair: CreateKeyPairResponse.KeyPair) -> [String] {

        guard var config = String(data: profileConfigData, encoding: .utf8) else {
            return []
        }

        if !isUDPAllowed {
            // swiftlint:disable:next force_try
            let remoteUdpRegex = try! NSRegularExpression(pattern: "remote.*udp", options: [])
            let fullStringRange = NSRange(location: 0, length: config.utf16.count)
            config = remoteUdpRegex.stringByReplacingMatches(
                in: config, options: [], range: fullStringRange, withTemplate: "")
        }

        guard let endOfCa = config.range(of: "</ca>")?.upperBound else {
            return []
        }

        config.insert(contentsOf: "\n<key>\n\(keyPair.privateKey)\n</key>", at: endOfCa)
        config.insert(contentsOf: "\n<cert>\n\(keyPair.certificate)\n</cert>", at: endOfCa)
        config = config.replacingOccurrences(of: "auth none\r\n", with: "")

        return config.components(separatedBy: .newlines)
    }
}

private extension ServerAPIService {
    func getFreshAccessToken(basicTargetInfo: BasicTargetInfo,
                             options: Options = []) -> Promise<String> {
        return firstly { () -> Promise<String> in
            if options.contains(.ignoreStoredAuthState) {
                throw StoredDataError.cannotUseStoredAuthState
            }
            guard let authState = basicTargetInfo.dataStore.authState else {
                throw StoredDataError.cannotUseStoredAuthState
            }
            return authState.getFreshAccessToken(storingChangesTo: basicTargetInfo.dataStore)
        }.recover { error -> Promise<String> in
            os_log("Error getting access token: %{public}@", log: Log.general, type: .error,
                   error.localizedDescription)
            switch error {
            case StoredDataError.cannotUseStoredAuthState,
                 AuthStateError.authStateUnauthorized:
                os_log("Starting fresh authentication", log: Log.general, type: .info)
                return self.serverAuthService.startAuth(
                    authEndpoint: basicTargetInfo.serverInfo.authorizationEndpoint,
                    tokenEndpoint: basicTargetInfo.serverInfo.tokenEndpoint,
                    from: basicTargetInfo.sourceViewController)
                .then { authState -> Promise<String> in
                    basicTargetInfo.dataStore.authState = authState
                    return authState.getFreshAccessToken(storingChangesTo: basicTargetInfo.dataStore)
                }
            default:
                throw error
            }
        }
    }
}

private extension X509Certificate {
    var isCurrentlyValid: Bool {
        return checkValidity()
    }

    var commonName: String? {
        if let commonNameElements = subjectDistinguishedName?.split(separator: "=") {
            if commonNameElements.count == 2 && commonNameElements[0] == "CN" {
                return String(commonNameElements[1])
            }
        }
        return nil
    }

    var expiresAt: Date? { notAfter }
}
