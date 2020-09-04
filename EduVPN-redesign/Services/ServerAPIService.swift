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
    case openVPNConfigHasInvalidEncoding
    case openVPNConfigHasNoCertificateAuthority
    case openVPNConfigHasNoRemotes
    case openVPNConfigHasOnlyUDPRemotes // and UDP is not allowed
}

extension ServerAPIServiceError: AppError {
    var summary: String {
        switch self {
        case .serverProvidedInvalidCertificate:
            return "Server provided invalid certificate"
        case .HTTPFailure:
            return "HTTP request failed"
        case .errorGettingProfileConfig:
            return "Error getting profile config"
        case .openVPNConfigHasInvalidEncoding:
            return "OpenVPN config has unrecognized encoding"
        case .openVPNConfigHasNoCertificateAuthority:
            return "OpenVPN config has no certificate authority"
        case .openVPNConfigHasNoRemotes:
            return "OpenVPN config has no remotes"
        case .openVPNConfigHasOnlyUDPRemotes:
            return "OpenVPN config has no TCP remotes, but only TCP can be used as per preferences"
        }
    }

    var detail: String {
        switch self {
        case .serverProvidedInvalidCertificate:
            return "Server provided invalid certificate"
        case .HTTPFailure(let requestURLPath, let response):
            return """
            Request path: \(requestURLPath)
            Response code: \(response.statusCode)
            Response: \(String(data: response.data, encoding: .utf8) ?? "")
            """
        case .errorGettingProfileConfig(let profile, let serverError):
            return """
            Requested profile: \(profile.displayName.string(for: Locale.current))
            Server error: \(serverError)
            """
        default:
            return ""
        }
    }
}

class ServerAPIService {

    struct Options: OptionSet {
        let rawValue: Int

        static let ignoreStoredAuthState = Options(rawValue: 1 << 0)
        static let ignoreStoredKeyPair = Options(rawValue: 1 << 1)
    }

    struct CertificateValidityRange {
        let validFrom: Date
        let expiresAt: Date
    }

    struct TunnelConfigurationData {
        let openVPNConfiguration: [String]
        let certificateValidityRange: CertificateValidityRange
    }

    struct KeyPairData {
        let keyPair: CreateKeyPairResponse.KeyPair
        let certificateValidityRange: CertificateValidityRange
    }

    static var uncachedSession: Moya.Session {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = nil
        return Session(configuration: configuration, startRequestsImmediately: false)
    }

    private let serverAuthService: ServerAuthService
    private var authStateChangeHandler: AuthStateChangeHandler?

    init(serverAuthService: ServerAuthService) {
        self.serverAuthService = serverAuthService
    }

    func getAvailableProfiles(for server: ServerInstance,
                              from viewController: AuthorizingViewController,
                              wayfSkippingInfo: ServerAuthService.WAYFSkippingInfo?,
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
                                    wayfSkippingInfo: wayfSkippingInfo,
                                    decodeAs: ProfileListResponse.self,
                                    options: options)
                .map { ($0, serverInfo) }
        }
    }

    func getTunnelConfigurationData(for server: ServerInstance, serverInfo: ServerInfo?,
                                    profile: ProfileListResponse.Profile,
                                    from viewController: AuthorizingViewController,
                                    wayfSkippingInfo: ServerAuthService.WAYFSkippingInfo?,
                                    options: Options = []) -> Promise<TunnelConfigurationData> {
        let dataStore = PersistenceService.DataStore(path: server.localStoragePath)
        return firstly { () -> Promise<ServerInfo> in
            if let serverInfo = serverInfo {
                return Promise.value(serverInfo)
            }
            return ServerInfoFetcher.fetch(apiBaseURLString: server.apiBaseURLString,
                                           authBaseURLString: server.authBaseURLString)
        }.then { serverInfo -> Promise<(BasicTargetInfo, KeyPairData)> in
            let basicTargetInfo = BasicTargetInfo(serverInfo: serverInfo,
                                                  dataStore: dataStore,
                                                  sourceViewController: viewController)
            return self.getKeyPair(basicTargetInfo: basicTargetInfo,
                                   wayfSkippingInfo: wayfSkippingInfo, options: options)
                .map { (basicTargetInfo, $0) }
        }.then { (basicTargetInfo, keyPairData) -> Promise<TunnelConfigurationData> in
            return firstly {
                self.getProfileConfig(basicTargetInfo: basicTargetInfo, profile: profile,
                                      wayfSkippingInfo: wayfSkippingInfo, options: options)
            }.map { profileConfig in
                let isUDPAllowed = !UserDefaults.standard.forceTCP
                let openVPNConfig = try Self.createOpenVPNConfig(
                    profileConfig: profileConfig, isUDPAllowed: isUDPAllowed, keyPair: keyPairData.keyPair)
                return TunnelConfigurationData(
                    openVPNConfiguration: openVPNConfig,
                    certificateValidityRange: keyPairData.certificateValidityRange)
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

    func makeRequest<T: ServerResponse>(target: ServerAPITarget,
                                        wayfSkippingInfo: ServerAuthService.WAYFSkippingInfo?,
                                        decodeAs responseType: T.Type,
                                        options: Options) -> Promise<T.DataType> {
        firstly { () -> Promise<String> in
            self.getFreshAccessToken(basicTargetInfo: target.basicTargetInfo, wayfSkippingInfo: wayfSkippingInfo)
        }.then { accessToken -> Promise<Moya.Response> in
            let authPlugin = AccessTokenPlugin { _ in accessToken }
            let provider = MoyaProvider<ServerAPITarget>(session: Self.uncachedSession, plugins: [authPlugin])
            return provider.request(target: target)
        }.then { response -> Promise<T.DataType> in
            if response.statusCode == Self.HTTPStatusCodeUnauthorized &&
                !options.contains(.ignoreStoredAuthState) {
                os_log("Encountered HTTP status code Unauthorized", log: Log.general, type: .info)
                return self.makeRequest(target: target, wayfSkippingInfo: wayfSkippingInfo,
                                        decodeAs: responseType,
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
                    wayfSkippingInfo: ServerAuthService.WAYFSkippingInfo?,
                    options: Options = []) -> Promise<KeyPairData> {
        firstly { () -> Promise<KeyPairData> in
            guard !options.contains(.ignoreStoredKeyPair),
                let storedKeyPair = basicTargetInfo.dataStore.keyPair,
                let certificateData = storedKeyPair.certificate.data(using: .utf8),
                let x509Certificate = try? X509Certificate(data: certificateData),
                x509Certificate.isCurrentlyValid,
                let commonName = x509Certificate.commonName,
                let expiresAt = x509Certificate.expiresAt,
                let validFrom = x509Certificate.validFrom else {
                    throw StoredDataError.cannotUseStoredKeyPair
            }
            return makeRequest(
                target: .checkCertificate(basicTargetInfo, commonName: commonName),
                wayfSkippingInfo: wayfSkippingInfo,
                decodeAs: CheckCertificateResponse.self, options: options)
                .map { certificateValidity in
                    guard certificateValidity.isValid else {
                        throw StoredDataError.cannotUseStoredKeyPair
                    }
                    let validityRange = CertificateValidityRange(validFrom: validFrom, expiresAt: expiresAt)
                    return KeyPairData(keyPair: storedKeyPair, certificateValidityRange: validityRange)
                }
        }.recover { error -> Promise<KeyPairData> in
            if case StoredDataError.cannotUseStoredKeyPair = error {
                return self.makeRequest(
                    target: .createKeyPair(basicTargetInfo, displayName: Config.shared.appName),
                    wayfSkippingInfo: wayfSkippingInfo,
                    decodeAs: CreateKeyPairResponse.self, options: options)
                    .map { keyPair in
                        basicTargetInfo.dataStore.keyPair = keyPair
                        guard let certificateData = keyPair.certificate.data(using: .utf8),
                            let x509Certificate = try? X509Certificate(data: certificateData),
                            x509Certificate.isCurrentlyValid,
                            let expiresAt = x509Certificate.expiresAt,
                            let validFrom = x509Certificate.validFrom else {
                                throw ServerAPIServiceError.serverProvidedInvalidCertificate
                        }
                        let validityRange = CertificateValidityRange(validFrom: validFrom, expiresAt: expiresAt)
                        return KeyPairData(keyPair: keyPair, certificateValidityRange: validityRange)
                    }
            } else {
                throw error
            }
        }
    }

    func getProfileConfig(basicTargetInfo: BasicTargetInfo, profile: ProfileListResponse.Profile,
                          wayfSkippingInfo: ServerAuthService.WAYFSkippingInfo?,
                          options: Options = []) -> Promise<Data> {
        firstly {
            makeRequest(target: .profileConfig(basicTargetInfo, profile: profile),
                        wayfSkippingInfo: wayfSkippingInfo,
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
        keyPair: CreateKeyPairResponse.KeyPair) throws -> [String] {

        guard let originalConfig = String(data: profileConfigData, encoding: .utf8) else {
            throw ServerAPIServiceError.openVPNConfigHasInvalidEncoding
        }

        let originalConfigLines = originalConfig.components(separatedBy: .newlines)
        let privateKeyLines = keyPair.privateKey.components(separatedBy: .newlines)
        let certificateLines = keyPair.certificate.components(separatedBy: .newlines)

        var hasCA = false
        var hasRemote = false

        var processedLines = [String]()
        for originalLine in originalConfigLines {
            let line = originalLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }
            if line.hasSuffix("auth none") { continue }

            if line.hasSuffix("</ca>") {
                processedLines.append(line)
                processedLines.append("<cert>")
                processedLines.append(contentsOf: certificateLines)
                processedLines.append("</cert>")
                processedLines.append("<key>")
                processedLines.append(contentsOf: privateKeyLines)
                processedLines.append("</key>")
                hasCA = true
                continue
            }

            if line.hasPrefix("remote") {
                let isUDPOnlyRemote = (line.hasSuffix(" udp") || line.hasSuffix(" udp4") || line.hasSuffix(" udp6"))
                if !isUDPOnlyRemote || isUDPAllowed {
                    processedLines.append(line)
                    hasRemote = true
                }
                continue
            }

            processedLines.append(line)
        }

        guard hasCA else {
            throw ServerAPIServiceError.openVPNConfigHasNoCertificateAuthority
        }

        guard hasRemote else {
            throw ServerAPIServiceError.openVPNConfigHasNoRemotes
        }

        return processedLines
    }
}

private extension ServerAPIService {

    enum AuthStateError: Error {
        case authStateUnauthorized(authorizationError: Error)
    }

    func getFreshAccessToken(basicTargetInfo: BasicTargetInfo,
                             wayfSkippingInfo: ServerAuthService.WAYFSkippingInfo?,
                             options: Options = []) -> Promise<String> {
        return firstly { () -> Promise<String> in
            if options.contains(.ignoreStoredAuthState) {
                throw StoredDataError.cannotUseStoredAuthState
            }
            guard let authState = basicTargetInfo.dataStore.authState else {
                throw StoredDataError.cannotUseStoredAuthState
            }
            return self.getFreshAccessToken(using: authState, storingChangesTo: basicTargetInfo.dataStore)
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
                    from: basicTargetInfo.sourceViewController,
                    wayfSkippingInfo: wayfSkippingInfo)
                .then { authState -> Promise<String> in
                    basicTargetInfo.dataStore.authState = authState
                    return self.getFreshAccessToken(using: authState, storingChangesTo: basicTargetInfo.dataStore)
                }
            default:
                throw error
            }
        }
    }

    func getFreshAccessToken(using authState: AuthState,
                             storingChangesTo dataStore: PersistenceService.DataStore)
        -> Promise<String> {
        return Promise { seal in
            let authStateChangeHandler = AuthStateChangeHandler(dataStore: dataStore)
            authState.oidAuthState.stateChangeDelegate = authStateChangeHandler
            self.authStateChangeHandler = authStateChangeHandler
            authState.oidAuthState.performAction { [weak self] (accessToken, _, error) in
                authState.oidAuthState.stateChangeDelegate = nil
                self?.authStateChangeHandler = nil
                if let authorizationError = authState.oidAuthState.authorizationError {
                    let error = AuthStateError.authStateUnauthorized(
                        authorizationError: authorizationError)
                    seal.reject(error)
                } else {
                    seal.resolve(accessToken, error)
                }
            }
        }
    }
}

private class AuthStateChangeHandler: NSObject, OIDAuthStateChangeDelegate {
    let dataStore: PersistenceService.DataStore

    init(dataStore: PersistenceService.DataStore) {
        self.dataStore = dataStore
    }

    func didChange(_ state: OIDAuthState) {
        dataStore.authState = AuthState(oidAuthState: state)
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

    var validFrom: Date? { notBefore }
    var expiresAt: Date? { notAfter }
}
