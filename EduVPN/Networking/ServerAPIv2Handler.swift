//
//  ServerAPIv2Handler.swift
//  EduVPN
//
//  Copyright © 2020-2021 The Commons Conservancy. All rights reserved.

import Foundation
import AppAuth
import Moya
import PromiseKit
import ASN1Decoder
import os.log

enum ServerAPIv2Error: Error {
    case serverProvidedInvalidCertificate
    case HTTPFailure(requestURLPath: String, response: Moya.Response)
    case errorGettingProfileConfig(profile: Profile, serverError: String)
    case openVPNConfigHasInvalidEncoding
    case openVPNConfigHasNoCertificateAuthority
    case openVPNConfigHasNoRemotes
    case openVPNConfigHasOnlyUDPRemotes // and UDP is not allowed
}

extension ServerAPIv2Error: AppError {
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
            Requested profile: \(profile.displayName.stringForCurrentLanguage())
            Server error: \(serverError)
            """
        default:
            return ""
        }
    }
}

struct ServerAPIv2Handler: ServerAPIHandler {
    static var authStateChangeHandler: AuthStateChangeHandler?

    static func getAvailableProfiles(
        commonInfo: ServerAPIService.CommonAPIRequestInfo,
        options: ServerAPIService.Options) -> Promise<[Profile]> {

        return Self.makeRequest(target: .profileList(commonInfo),
                           decodeAs: ProfileListResponsev2.self,
                           options: options)
    }

    static func getTunnelConfigurationData(
        commonInfo: ServerAPIService.CommonAPIRequestInfo,
        profile: Profile,
        options: ServerAPIService.Options) -> Promise<ServerAPIService.TunnelConfigurationData> {

        firstly { () -> Promise<KeyPairData> in
            return Self.getKeyPair(commonInfo: commonInfo, options: options)
        }.then { keyPairData -> Promise<ServerAPIService.TunnelConfigurationData> in
            // Can reuse the auth state we just got from getKeyPair
            let updatedOptions = options.subtracting([.ignoreStoredAuthState])
            return firstly {
                Self.getProfileConfig(commonInfo: commonInfo,
                                      profile: profile,
                                      options: updatedOptions)
            }.map { profileConfig in
                let isUDPAllowed = !UserDefaults.standard.forceTCP
                let openVPNConfig = try Self.createOpenVPNConfig(
                    profileConfig: profileConfig, isUDPAllowed: isUDPAllowed, keyPair: keyPairData.keyPair)
                return ServerAPIService.TunnelConfigurationData(
                    vpnConfig: .openVPNConfig(openVPNConfig),
                    expiresAt: keyPairData.certificateExpiryDate,
                    serverAPIBaseURL: commonInfo.serverInfo.apiBaseURL,
                    serverAPIVersion: commonInfo.serverInfo.apiVersion)
            }
        }
    }

    static func attemptToRelinquishTunnelConfiguration(
        baseURL: URL, dataStore: PersistenceService.DataStore, session: Moya.Session,
        profile: Profile, shouldFireAndForget: Bool) -> Promise<Void> {
        // Nothing to do
        return Promise.value(())
    }
}

private extension ServerAPIv2Handler {

    enum ServerAPITarget: TargetType, AcceptJson, AccessTokenAuthorizable {
        case profileList(ServerAPIService.CommonAPIRequestInfo)
        case createKeyPair(ServerAPIService.CommonAPIRequestInfo, displayName: String)
        case checkCertificate(ServerAPIService.CommonAPIRequestInfo, commonName: String)
        case profileConfig(ServerAPIService.CommonAPIRequestInfo, profile: Profile)

        var commonInfo: ServerAPIService.CommonAPIRequestInfo {
            switch self {
            case .profileList(let commonInfo): return commonInfo
            case .createKeyPair(let commonInfo, _): return commonInfo
            case .checkCertificate(let commonInfo, _): return commonInfo
            case .profileConfig(let commonInfo, _): return commonInfo
            }
        }

        var baseURL: URL { commonInfo.serverInfo.apiBaseURL }

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

    struct KeyPairData {
        let keyPair: CreateKeyPairResponse.KeyPair
        let certificateExpiryDate: Date
    }

    static func makeRequest<T: ServerResponse>(
        target: ServerAPITarget,
        decodeAs responseType: T.Type,
        options: ServerAPIService.Options) -> Promise<T.DataType> {

        firstly { () -> Promise<String> in
            Self.getFreshAccessToken(
                commonInfo: target.commonInfo,
                options: options)
        }.then { accessToken -> Promise<Moya.Response> in
            let authPlugin = AccessTokenPlugin { _ in accessToken }
            let provider = MoyaProvider<ServerAPITarget>(session: target.commonInfo.session, plugins: [authPlugin])
            return provider.request(target: target)
        }.then { response -> Promise<T.DataType> in
            if response.statusCode == Self.HTTPStatusCodeUnauthorized &&
                !options.contains(.ignoreStoredAuthState) {
                os_log("Encountered HTTP status code Unauthorized", log: Log.general, type: .info)
                return Self.makeRequest(
                    target: target,
                    decodeAs: responseType,
                    options: options.union([.ignoreStoredAuthState]))
            } else {
                let successStatusCodes = (200...299)
                guard successStatusCodes.contains(response.statusCode) else {
                    throw ServerAPIv2Error.HTTPFailure(requestURLPath: target.path, response: response)
                }
                return Promise.value(try T(data: response.data).data)
            }
        }
    }

    static func getKeyPair(
        commonInfo: ServerAPIService.CommonAPIRequestInfo,
        options: ServerAPIService.Options) -> Promise<KeyPairData> {

        firstly { () -> Promise<KeyPairData> in
            guard !options.contains(.ignoreStoredKeyPair),
                let storedKeyPair = commonInfo.dataStore.keyPair,
                let certificateData = storedKeyPair.certificate.data(using: .utf8),
                let x509Certificate = try? X509Certificate(data: certificateData),
                x509Certificate.isCurrentlyValid,
                let commonName = x509Certificate.commonName,
                let expiresAt = x509Certificate.expiresAt else {
                throw ServerAPIServiceError.cannotUseStoredKeyPair
            }
            return makeRequest(
                target: .checkCertificate(commonInfo, commonName: commonName),
                decodeAs: CheckCertificateResponse.self, options: options)
                .map { certificateValidity in
                    guard certificateValidity.isValid else {
                        throw ServerAPIServiceError.cannotUseStoredKeyPair
                    }
                    return KeyPairData(keyPair: storedKeyPair, certificateExpiryDate: expiresAt)
                }
        }.recover { error -> Promise<KeyPairData> in
            if case ServerAPIServiceError.cannotUseStoredKeyPair = error {
                return Self.makeRequest(
                    target: .createKeyPair(commonInfo, displayName: Config.shared.appName),
                    decodeAs: CreateKeyPairResponse.self, options: options)
                    .map { keyPair in
                        commonInfo.dataStore.keyPair = keyPair
                        guard let certificateData = keyPair.certificate.data(using: .utf8),
                            let x509Certificate = try? X509Certificate(data: certificateData),
                            x509Certificate.isCurrentlyValid,
                            let expiresAt = x509Certificate.expiresAt else {
                                throw ServerAPIv2Error.serverProvidedInvalidCertificate
                        }
                        return KeyPairData(keyPair: keyPair, certificateExpiryDate: expiresAt)
                    }
            } else {
                throw error
            }
        }
    }

    static func getProfileConfig(
        commonInfo: ServerAPIService.CommonAPIRequestInfo,
        profile: Profile,
        options: ServerAPIService.Options) -> Promise<Data> {

        firstly {
            makeRequest(target: .profileConfig(commonInfo, profile: profile),
                        decodeAs: ProfileConfigResponse.self, options: options)
        }.map { data in
            if let errorResponse = try? JSONDecoder().decode(ProfileConfigErrorResponsev2.self, from: data) {
                throw ServerAPIv2Error.errorGettingProfileConfig(profile: profile, serverError: errorResponse.errorMessage)
            }
            return data
        }
    }

    static func createOpenVPNConfig(
        profileConfig profileConfigData: Data,
        isUDPAllowed: Bool,
        keyPair: CreateKeyPairResponse.KeyPair) throws -> [String] {

        guard let originalConfig = String(data: profileConfigData, encoding: .utf8) else {
            throw ServerAPIv2Error.openVPNConfigHasInvalidEncoding
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
            throw ServerAPIv2Error.openVPNConfigHasNoCertificateAuthority
        }

        guard hasRemote else {
            throw ServerAPIv2Error.openVPNConfigHasNoRemotes
        }

        return processedLines
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
