//
//  ServerAPIv3Handler.swift
//  EduVPN
//
//  Copyright © 2020-2021 The Commons Conservancy. All rights reserved.

import Foundation
import Moya
import PromiseKit
import WireGuardKit
import os.log

enum ServerAPIv3Error: Error {
    case HTTPFailure(requestURLPath: String, response: Moya.Response)
    case errorGettingProfileConfig(profile: Profile, serverError: String)
    case VPNConfigHasInvalidEncoding
    case wgVPNConfigMissingInterfaceSection
    case expiresResponseHeaderIsInvalid(String?)
    case unexpectedContentTypeOnConnect(String?)
    case fireAndForgetCallTimedOut
}

extension ServerAPIv3Error: AppError {
    var summary: String {
        switch self {
        case .HTTPFailure:
            return "HTTP request failed"
        case .errorGettingProfileConfig:
            return "Error getting profile config"
        case .VPNConfigHasInvalidEncoding:
            return "VPN config has unrecognized encoding"
        case .wgVPNConfigMissingInterfaceSection:
            return "WireGuard VPN config is missing its 'Interface' section"
        case .expiresResponseHeaderIsInvalid:
            return "Invalid expiration date value"
        case .unexpectedContentTypeOnConnect:
            return "Unexpected content type value"
        case .fireAndForgetCallTimedOut:
            return "Disconnect call timed out"
        }
    }

    var detail: String {
        switch self {
        case .HTTPFailure(let requestURLPath, let response):
            return """
            Request path: \(requestURLPath)
            Response code: \(response.statusCode)
            Response: \(String(data: response.data, encoding: .utf8) ?? "")
            """
        case .errorGettingProfileConfig(let profile, let serverError):
            return """
            Requested profile name: \(profile.displayName.stringForCurrentLanguage())
            Requested profile id: \(profile.profileId)
            Server error: \(serverError)
            """
        case .expiresResponseHeaderIsInvalid(let value):
            if let value = value {
                return "The 'Expires' HTTP response header value returned was: \(value)"
            } else {
                return "No 'Expires' HTTP response header was returned"
            }
        case .unexpectedContentTypeOnConnect(let value):
            if let value = value {
                return "The 'Content-Type' HTTP response header value returned was: \(value)"
            } else {
                return "No 'Content-Type' HTTP response header was returned"
            }
        default:
            return ""
        }
    }
}

struct ServerAPIv3Handler: ServerAPIHandler {
    static var authStateChangeHandler: AuthStateChangeHandler?

    static func getAvailableProfiles(
        commonInfo: ServerAPIService.CommonAPIRequestInfo,
        options: ServerAPIService.Options) -> Promise<[Profile]> {

        return Self.makeRequest(
            target: .info(commonInfo),
            decodeAs: InfoResponse.self,
            options: options)
            .map { $0.data }
    }

    static func getTunnelConfigurationData(
        commonInfo: ServerAPIService.CommonAPIRequestInfo,
        profile: Profile,
        options: ServerAPIService.Options) -> Promise<ServerAPIService.TunnelConfigurationData> {

        let privateKey: WireGuardKit.PrivateKey = {
            // If a valid WireGuard private key is stored, return it.
            // Else, create a new private key, store it, and return it.
            guard let keyData = commonInfo.dataStore.wireGuardPrivateKey,
                  let key = WireGuardKit.PrivateKey(rawValue: keyData) else {
                let newKey = WireGuardKit.PrivateKey()
                commonInfo.dataStore.wireGuardPrivateKey = newKey.rawValue
                return newKey
            }
            return key
        }()
        let publicKey = privateKey.publicKey.base64Key

        return firstly {
            return Self.makeRequest(
                target: .connect(commonInfo, profile: profile, publicKey: publicKey,
                                 isTCPOnly: UserDefaults.standard.forceTCP),
                decodeAs: ConnectResponse.self,
                options: options)
        }.map { responseData -> ServerAPIService.TunnelConfigurationData in
            guard let configString = String(data: responseData.data, encoding: .utf8) else {
                throw ServerAPIv3Error.VPNConfigHasInvalidEncoding
            }
            guard let expiresString = responseData.expiresResponseHeader else {
                throw ServerAPIv3Error.expiresResponseHeaderIsInvalid(nil)
            }

            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = "EEE',' dd' 'MMM' 'yyyy HH':'mm':'ss zzz"
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            guard let expiresDate = dateFormatter.date(from: expiresString) else {
                throw ServerAPIv3Error.expiresResponseHeaderIsInvalid(expiresString)
            }

            let authenticationTime = commonInfo.dataStore.authenticationTime

            switch responseData.contentTypeResponseHeader {
            case "application/x-openvpn-profile":
                let configLines = configString.split(separator: "\n").map { String($0) }
                return ServerAPIService.TunnelConfigurationData(
                    vpnConfig: .openVPNConfig(configLines),
                    expiresAt: expiresDate,
                    authenticationTime: authenticationTime,
                    serverAPIBaseURL: commonInfo.serverInfo.apiBaseURL,
                    serverAPIVersion: commonInfo.serverInfo.apiVersion)
            case "application/x-wireguard-profile":
                let updatedConfigString = try insertPrivateKey(privateKey, in: configString)
                return ServerAPIService.TunnelConfigurationData(
                    vpnConfig: .wireGuardConfig(updatedConfigString),
                    expiresAt: expiresDate,
                    authenticationTime: authenticationTime,
                    serverAPIBaseURL: commonInfo.serverInfo.apiBaseURL,
                    serverAPIVersion: commonInfo.serverInfo.apiVersion)
            default:
                throw ServerAPIv3Error.unexpectedContentTypeOnConnect(responseData.contentTypeResponseHeader)
            }
        }
    }

    static func attemptToRelinquishTunnelConfiguration(
        baseURL: URL, dataStore: PersistenceService.DataStore, session: Moya.Session,
        profile: Profile, shouldFireAndForget: Bool) -> Promise<Void> {
        let target: FireAndForgetAPITarget = .disconnect(
            baseURL: baseURL, dataStore: dataStore, session: session)
        if shouldFireAndForget {
            Self.fireAndForget(target: target)
            return Promise.value(())
        } else {
            return Self.fire(target: target, timeout: 3 /* seconds */)
        }
    }
}

private extension ServerAPIv3Handler {
    enum ServerAPITarget: TargetType, AcceptJson, AccessTokenAuthorizable {
        case info(ServerAPIService.CommonAPIRequestInfo)
        case connect(ServerAPIService.CommonAPIRequestInfo, profile: Profile, publicKey: String, isTCPOnly: Bool)

        var commonInfo: ServerAPIService.CommonAPIRequestInfo {
            switch self {
            case .info(let commonInfo): return commonInfo
            case .connect(let commonInfo, _, _, _): return commonInfo
            }
        }

        var baseURL: URL { commonInfo.serverInfo.apiBaseURL }

        var path: String {
            switch self {
            case .info: return "/info"
            case .connect: return "/connect"
            }
        }

        var method: Moya.Method {
            switch self {
            case .info: return .get
            case .connect: return .post
            }
        }

        var sampleData: Data { Data() }

        var task: Task {
            switch self {
            case .info:
                return .requestPlain
            case .connect(_, let profile, let publicKey, let isTCPOnly):
                return .requestParameters(
                    parameters: [
                        "profile_id": profile.profileId,
                        "public_key": publicKey,
                        "prefer_tcp": isTCPOnly ? "yes" : "no"
                    ],
                    encoding: URLEncoding.httpBody)
            }
        }

        var authorizationType: AuthorizationType? { .bearer }
    }

    static let HTTPStatusCodeUnauthorized = 401

    struct ResponseData<T: ServerResponse> {
        let data: T.DataType
        let contentTypeResponseHeader: String?
        let expiresResponseHeader: String?
    }

    static func makeRequest<T: ServerResponse>(
        target: ServerAPITarget,
        decodeAs responseType: T.Type,
        options: ServerAPIService.Options) -> Promise<ResponseData<T>> {

        firstly { () -> Promise<String> in
            Self.getFreshAccessToken(
                commonInfo: target.commonInfo,
                options: options)
        }.then { accessToken -> Promise<Moya.Response> in
            let authPlugin = AccessTokenPlugin { _ in accessToken }
            let provider = MoyaProvider<ServerAPITarget>(session: target.commonInfo.session, plugins: [authPlugin])
            return provider.request(target: target)
        }.then { response -> Promise<ResponseData<T>> in
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
                    if case .connect(_, let profile, _, _) = target,
                       let errorResponse = try? JSONDecoder().decode(ProfileConfigErrorResponse.self, from: response.data) {
                        throw ServerAPIv3Error.errorGettingProfileConfig(
                            profile: profile, serverError: errorResponse.errorMessage)
                    }
                    throw ServerAPIv3Error.HTTPFailure(requestURLPath: target.path, response: response)
                }
                let data = try T(data: response.data).data
                let httpResponse = response.response
                let contentType: String?
                let expires: String?
                if #available(iOS 13.0, macOS 10.15, *) {
                    contentType = httpResponse?.value(forHTTPHeaderField: "Content-Type")
                    expires = httpResponse?.value(forHTTPHeaderField: "Expires")
                } else {
                    let allHeaders = httpResponse?.allHeaderFields
                    contentType = allHeaders?["Content-Type"] as? String
                    expires = allHeaders?["Expires"] as? String
                }
                let responseData = ResponseData<T>(
                    data: data,
                    contentTypeResponseHeader: contentType,
                    expiresResponseHeader: expires)
                return Promise.value(responseData)
            }
        }
    }
}

private extension ServerAPIv3Handler {
    enum FireAndForgetAPITarget: TargetType, AcceptJson, AccessTokenAuthorizable {
        case disconnect(baseURL: URL, dataStore: PersistenceService.DataStore,
                        session: Moya.Session)

        var dataStore: PersistenceService.DataStore {
            switch self {
            case .disconnect(_, let dataStore, _): return dataStore
            }
        }

        var session: Moya.Session {
            switch self {
            case .disconnect(_, _, let session): return session
            }
        }

        var baseURL: URL {
            switch self {
            case .disconnect(let baseURL, _, _): return baseURL
            }
        }

        var path: String {
            switch self {
            case .disconnect: return "/disconnect"
            }
        }

        var method: Moya.Method {
            switch self {
            case .disconnect: return .post
            }
        }

        var sampleData: Data { Data() }

        var task: Task {
            switch self {
            case .disconnect:
                return .requestPlain
            }
        }

        var authorizationType: AuthorizationType? { .bearer }
    }

    private static func fire(target: FireAndForgetAPITarget) -> Promise<Void> {
        firstly { () -> Promise<String> in
            if let authState = target.dataStore.authState {
                return Self.getFreshAccessToken(using: authState, storingChangesTo: target.dataStore)
            } else {
                os_log("Not firing call to '%@' because there's no stored auth state", target.path)
                throw ServerAPIServiceError.cannotUseStoredAuthState
            }
        }.then { accessToken -> Promise<Moya.Response> in
            let authPlugin = AccessTokenPlugin { _ in accessToken }
            let provider = MoyaProvider<FireAndForgetAPITarget>(session: target.session, plugins: [authPlugin])
            return provider.request(target: target)
        }.map { response in
            if response.statusCode == Self.HTTPStatusCodeUnauthorized {
                os_log("Encountered HTTP status code Unauthorized on firing call to '%@'", log: Log.general, type: .debug,
                       target.path)
            } else {
                let successStatusCodes = (200...299)
                guard successStatusCodes.contains(response.statusCode) else {
                    os_log("Encountered HTTP failure on firing call to '%@': %@", log: Log.general, type: .debug,
                           target.path, response.debugDescription)
                    return
                }
            }
        }
    }

    static func fire(target: FireAndForgetAPITarget, timeout: TimeInterval) -> Promise<Void> {
        let timedPromise = after(seconds: timeout).done {
            throw ServerAPIv3Error.fireAndForgetCallTimedOut
        }
        return race(fire(target: target), timedPromise)
    }

    static func fireAndForget(target: FireAndForgetAPITarget) {
        fire(target: target).cauterize()
    }
}

private extension ServerAPIv3Handler {
    static func insertPrivateKey(
        _ privateKey: WireGuardKit.PrivateKey,
        in wgQuickConfig: String) throws -> String {

        guard let interfaceRange = wgQuickConfig.range(of: "[Interface]") else {
            throw ServerAPIv3Error.wgVPNConfigMissingInterfaceSection
        }
        var config = wgQuickConfig
        config.insert(
            contentsOf: "\nPrivateKey = \(privateKey.base64Key)\n",
            at: interfaceRange.upperBound)
        return config
    }
}
