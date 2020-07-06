//
//  ServerApiService.swift
//  EduVPN
//
//  Created by Johan Kool on 24/06/2020.
//

import Foundation
import PromiseKit
import Moya
import os.log

protocol ServerApiServiceType {
    func profileConfig(for profile: Profile) -> Promise<[String]>
}

enum ServerApiServiceError: Error {
    case apiMissing
    case profileIdMissing
    case apiProviderCreateFailed
    case certificateCommonNameNotFound
    case ovpnConfigTemplate
    case certificateModelMissing
    case certificateInvalid
    case certificateStatusUnknown
    case certificateNil
    case ovpnTemplate
    case ovpnConfigTemplateNoRemotes
}

class ServerApiService: ServerApiServiceType {
    
    func profileConfig(for profile: Profile) -> Promise<[String]> {
        guard let api = profile.api else {
            precondition(false, "This should never happen")
            return Promise(error: ServerApiServiceError.apiMissing)
        }
        
        guard let profileId = profile.profileId else {
            precondition(false, "This should never happen")
            return Promise(error: ServerApiServiceError.profileIdMissing)
        }
        
        guard let dynamicApiProvider = DynamicApiProvider(api: api) else {
            return Promise(error: ServerApiServiceError.apiProviderCreateFailed)
        }
               
        return loadCertificate(for: api)
                .then { _ -> Promise<Response> in
//                    self.setActivityIndicatorMessage(key: "Requesting profile config")
                    return dynamicApiProvider.request(apiService: .profileConfig(profileId: profileId))
                }.map { response -> [String] in
                    guard var ovpnFileContent = String(data: response.data, encoding: .utf8) else {
                        throw ServerApiServiceError.ovpnConfigTemplate
                    }

                    ovpnFileContent = self.forceTcp(on: ovpnFileContent)
                    try self.validateRemote(on: ovpnFileContent)

                    guard let certificateModel = api.certificateModel else {
                        throw ServerApiServiceError.certificateModelMissing
                    }
                    ovpnFileContent = try self.merge(key: certificateModel.privateKeyString, certificate: certificateModel.certificateString, into: ovpnFileContent)
                    let lines = ovpnFileContent.components(separatedBy: .newlines).map {
                        $0.trimmingCharacters(in: .whitespacesAndNewlines)
                    }.filter {
                        !$0.isEmpty
                    }

                    return lines
                }.recover { (error) throws -> Promise<[String]> in
//                    if retry {
//                        self.showError(error)
//                        throw error
//                    }

                    if let nsError = error as NSError?, nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorNetworkConnectionLost {
                        return self.retryFetchProfile(with: dynamicApiProvider, for: profile)
                    }

                    switch error {

                    case ApiServiceError.tokenRefreshFailed, ApiServiceError.noAuthState :
                        return self.retryFetchProfile(with: dynamicApiProvider, for: profile)

                    default:
//                        return self.hideActivityIndicator().then { _ -> Guarantee<[String]> in
//                            self.showError(error)
                            throw error
//                        }
                    }
                    
                }
    }
    
    private func fetchProfile(for profile: Profile, retry: Bool = false) -> Promise<[String]> {
        guard let api = profile.api else {
            precondition(false, "This should never happen")
            return Promise(error: ServerApiServiceError.apiMissing)
        }

        guard let profileId = profile.profileId else {
            precondition(false, "This should never happen")
            return Promise(error: ServerApiServiceError.profileIdMissing)
        }

        guard let dynamicApiProvider = DynamicApiProvider(api: api) else {
            return Promise(error: ServerApiServiceError.apiProviderCreateFailed)
        }
        
//        setActivityIndicatorMessage(key: "Loading certificate")
        
        return loadCertificate(for: api)
            .then { _ -> Promise<Response> in
//                self.setActivityIndicatorMessage(key: "Requesting profile config")
                return dynamicApiProvider.request(apiService: .profileConfig(profileId: profileId))
            }.map { response -> [String] in
                guard var ovpnFileContent = String(data: response.data, encoding: .utf8) else {
                    throw ServerApiServiceError.ovpnConfigTemplate
                }
                
                ovpnFileContent = self.forceTcp(on: ovpnFileContent)
                try self.validateRemote(on: ovpnFileContent)

                guard let certificateModel = api.certificateModel else {
                    throw ServerApiServiceError.certificateModelMissing
                }
                ovpnFileContent = try self.merge(key: certificateModel.privateKeyString, certificate: certificateModel.certificateString, into: ovpnFileContent)
                let lines = ovpnFileContent.components(separatedBy: .newlines).map {
                    $0.trimmingCharacters(in: .whitespacesAndNewlines)
                }.filter {
                    !$0.isEmpty
                }

                return lines
            }.recover { (error) throws -> Promise<[String]> in
                if retry {
//                    self.showError(error)
                    throw error
                }
                
                if let nsError = error as NSError?, nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorNetworkConnectionLost {
                    return self.retryFetchProfile(with: dynamicApiProvider, for: profile)
                }
                
                switch error {
                    
                case ApiServiceError.tokenRefreshFailed, ApiServiceError.noAuthState :
                    return self.retryFetchProfile(with: dynamicApiProvider, for: profile)

                default:
//                    return self.hideActivityIndicator().then { _ -> Guarantee<[String]> in
//                        self.showError(error)
                        throw error
//                    }
                }
            }
    }
    
    private func retryFetchProfile(with dynamicApiProvider: DynamicApiProvider, for profile: Profile) -> Promise<[String]> {
        // self.authorizingDynamicApiProvider = dynamicApiProvider
         #if os(iOS)
         let authorizeRequest = dynamicApiProvider.authorize(presentingViewController: self.navigationController)
//         self.showActivityIndicator(messageKey: "Authorizing with provider")
         #elseif os(macOS)
         let authorizeRequest = dynamicApiProvider.authorize()
//         self.showActivityIndicator(messageKey: "Authorizing with provider", cancellable: authorizeRequest)
         #endif

         return authorizeRequest.then { _ -> Promise<[String]> in
            return self.fetchProfile(for: profile, retry: true)
//             return self.hideActivityIndicator().then { _ -> Promise<[String]> in
//                 #if os(macOS)
////                 NSApp.activate(ignoringOtherApps: true)
//                 #endif
//                 return self.fetchProfile(for: profile, retry: true)
//             }
         }
     }
    
    private func loadCertificate(for api: Api) -> Promise<CertificateModel> {
           guard let dynamicApiProvider = DynamicApiProvider(api: api) else {
               return Promise(error: ServerApiServiceError.apiProviderCreateFailed)
           }
           
           if let certificateModel = api.certificateModel {
               if let certificate = certificateModel.x509Certificate, certificate.checkValidity() {
                   return checkCertificate(api: api, for: dynamicApiProvider).recover { error -> Promise<CertificateModel> in
                       switch error {
                           
                       case ServerApiServiceError.certificateInvalid, ServerApiServiceError.certificateNil, ServerApiServiceError.certificateCommonNameNotFound:
                           api.certificateModel = nil
                           return self.loadCertificate(for: api)
                           
                       default:
                           throw error
                           
                       }
                   }
               } else {
                   api.certificateModel = nil
               }
           }

           return fetchCertificate(for: api, useAuthState: true)
       }
    
    /// Fetch a certificate from the server.
    ///
    /// If we use the existing valid authState or the existing valid browser
    /// session, the certificate we get from the server would be bound to
    /// the lifetime of the refresh_token / browser session.
    /// If called with `useAuthState` false after the browser session expires,
    /// we can get a fresh certificate that would be valid for a longer time
    /// (compared to using an existing valid authState).
    private func fetchCertificate(for api: Api, useAuthState: Bool) -> Promise<CertificateModel> {
        guard let dynamicApiProvider = DynamicApiProvider(api: api) else {
            return Promise(error: ServerApiServiceError.apiProviderCreateFailed)
        }

        guard let appName: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String else {
            fatalError("An app should always have a `CFBundleName`.")
        }

        #if os(iOS)
        let keyPairDisplayName = "\(appName) for iOS"
        #elseif os(macOS)
        let keyPairDisplayName = "\(appName) for macOS"
        #endif

        return firstly { () throws -> Promise<Moya.Response> in
            guard useAuthState else { throw ApiServiceError.noAuthState }
            return dynamicApiProvider.request(apiService: .createKeypair(displayName: keyPairDisplayName))
        }.recover { error throws -> Promise<Response> in
            if case ApiServiceError.noAuthState = error {
                #if os(iOS)
                let authorize = dynamicApiProvider.authorize(presentingViewController: self.navigationController)
                #elseif os(macOS)
                let authorize = dynamicApiProvider.authorize()
                #endif
                return authorize.then { _ -> Promise<Response> in
                    return dynamicApiProvider.request(apiService: .createKeypair(displayName: keyPairDisplayName))
                }
            } else {
                throw error
            }
        }.then { response -> Promise<CertificateModel> in
            response.mapResponse()
        }.map { model -> CertificateModel in
            if let certificateExpiryDate = model.x509Certificate?.notAfter {
                os_log("fetchCertificate: certificate expires at: %{public}@",
                       log: Log.general, type: .error, certificateExpiryDate as NSDate)
            }
            api.certificateModel = model
            return model
        }
    }

    private func checkCertificate(api: Api, for dynamicApiProvider: DynamicApiProvider) -> Promise<CertificateModel> {
        guard let certificateModel = api.certificateModel else {
            return Promise<CertificateModel>(error: ServerApiServiceError.certificateNil)
        }
        
        guard let commonNameElements = certificateModel.x509Certificate?.subjectDistinguishedName?.split(separator: "=") else {
            return Promise<CertificateModel>(error: ServerApiServiceError.certificateCommonNameNotFound)
        }
        
        guard commonNameElements.count == 2, commonNameElements[0] == "CN" else {
            return Promise<CertificateModel>(error: ServerApiServiceError.certificateCommonNameNotFound)
        }
        
        let commonName = String(commonNameElements[1])
        return dynamicApiProvider.request(apiService: .checkCertificate(commonName: commonName)).then { response throws -> Promise<CertificateModel> in
            
            if response.statusCode == 404 {
                return .value(certificateModel)
            }
            
            if let jsonResult = try response.mapJSON() as? [String: AnyObject],
                let checkResult = jsonResult["check_certificate"] as? [String: AnyObject],
                let dataResult = checkResult["data"] as? [String: AnyObject],
                let isValidResult = dataResult["is_valid"] as? Bool {
                
                if isValidResult {
                    return .value(certificateModel)
                } else {
                    api.certificateModel = nil
                    throw ServerApiServiceError.certificateInvalid
                }
            } else {
                throw ServerApiServiceError.certificateStatusUnknown
            }
        }.recover { (error) throws -> Promise<CertificateModel> in
            if case ApiServiceError.unauthorized = error {
                #if os(iOS)
                
                return dynamicApiProvider.authorize(presentingViewController: self.navigationController).then { _ -> Promise<CertificateModel> in
                    return self.checkCertificate(api: api, for: dynamicApiProvider)
                }
                
                #elseif os(macOS)
                
                return dynamicApiProvider.authorize().then { _ -> Promise<CertificateModel> in
                    return self.checkCertificate(api: api, for: dynamicApiProvider)
                }
                
                #endif
               
            }

            throw error
        }
    }
    
    /// merge ovpn profile with keypair
    private func merge(key: String, certificate: String, into ovpnFileContent: String) throws -> String {
        var ovpnFileContent = ovpnFileContent
        
        guard let caRange = ovpnFileContent.range(of: "</ca>") else {
            throw ServerApiServiceError.ovpnTemplate
        }
        let insertionIndex = caRange.upperBound
        ovpnFileContent.insert(contentsOf: "\n<key>\n\(key)\n</key>", at: insertionIndex)
        ovpnFileContent.insert(contentsOf: "\n<cert>\n\(certificate)\n</cert>", at: insertionIndex)
        ovpnFileContent = ovpnFileContent.replacingOccurrences(of: "auth none\r\n", with: "")
        
        return ovpnFileContent
    }
    
    private func forceTcp(on ovpnFileContent: String) -> String {
        guard UserDefaults.standard.forceTcp else {
            return ovpnFileContent
        }
        
        var ovpnFileContent = ovpnFileContent
        guard let remoteUdpRegex = try? NSRegularExpression(pattern: "remote.*udp", options: []) else {
            fatalError("Regular expression has been validated to compile, should not fail.")
        }
        
        ovpnFileContent = remoteUdpRegex.stringByReplacingMatches(in: ovpnFileContent,
                                                                  options: [],
                                                                  range: NSRange(location: 0,
                                                                                 length: ovpnFileContent.utf16.count),
                                                                  withTemplate: "")
        
        return ovpnFileContent
    }
    
    private func validateRemote(on ovpnFileContent: String) throws {
        guard let remoteTcpRegex = try? NSRegularExpression(pattern: "remote.*", options: []) else {
            fatalError("Regular expression has been validated to compile, should not fail.")
        }
        
        if remoteTcpRegex.numberOfMatches(in: ovpnFileContent, options: [], range: NSRange(location: 0, length: ovpnFileContent.utf16.count)) == 0 {
            throw ServerApiServiceError.ovpnConfigTemplateNoRemotes
        }
    }
}
