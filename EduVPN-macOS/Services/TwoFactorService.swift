//
//  TwoFactorService.swift
//  eduVPN
//
//  Created by Johan Kool on 16/04/2018.
//  Copyright © 2017-2019 Commons Conservancy.
//

import Foundation
import AppKit

class TwoFactorService {
    
    enum Error: Swift.Error, LocalizedError {
        case unknown
        case invalidTwoFactor
        case invalidProviderInfo
        case userAlreadyEnrolled
        case missingToken
        
        var errorDescription: String? {
            switch self {
            case .unknown:
                return NSLocalizedString("An unknown error occurred", comment: "")
            case .invalidTwoFactor:
                return NSLocalizedString("Invalid two factor info", comment: "")
            case .invalidProviderInfo:
                return NSLocalizedString("Invalid provider info", comment: "")
            case .userAlreadyEnrolled:
                return NSLocalizedString("You already did setup two factor authentication", comment: "")
            case .missingToken:
                return NSLocalizedString("No valid token was available", comment: "")
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .userAlreadyEnrolled:
                return NSLocalizedString("Use previously setup two factor authentication instead.", comment: "")
            default:
                return NSLocalizedString("Try again later.", comment: "")
            }
        }
    }
    
    private let urlSession: URLSession
    private let authenticationService: AuthenticationService
    
    init(urlSession: URLSession, authenticationService: AuthenticationService) {
        self.urlSession = urlSession
        self.authenticationService = authenticationService
    }
    
    /// Enroll user with Yubico 2FA at provider
    ///
    /// - Parameters:
    ///   - info: Provider info
    ///   - handler: Success or error
    func enrollYubico(for info: ProviderInfo, otp: String, handler: @escaping (Result<Void>) -> ()) {
        let path: String = "two_factor_enroll_yubi"
        
        guard let url = URL(string: path, relativeTo: info.apiBaseURL) else {
            handler(.failure(Error.invalidProviderInfo))
            return
        }
        
        authenticationService.performAction(for: info) { (accessToken, idToken, error) in
            guard let accessToken = accessToken else {
                handler(.failure(error ?? Error.missingToken))
                return
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = "yubi_key_otp=\(otp)".data(using: .utf8)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            
            self.performEnrollmentRequest(request, handler: handler)
        }
    }
    
    /// Generates totp secret
    ///
    /// - Returns: Base32 encoded (only upper case) string made up of 20 random bytes (160 bits)
    func generateSecret() -> String {
        return String.random()
    }
    
    /// Generates URL for compatible TOTP applications
    ///
    /// - Parameters:
    ///   - secret: Totp secret
    ///   - provider: Provider info
    /// - Returns: URL
    func generateURL(secret: String, provider: ProviderInfo) -> URL {
        // URL constructed based on https://github.com/google/google-authenticator/wiki/Key-Uri-Format
        var url = URLComponents()
        url.scheme = "otpauth"
        url.host = "totp"
        let issuer = provider.apiBaseURL.host ?? "eduVPN"
        url.path = "/" + issuer
        url.queryItems = [URLQueryItem(name: "secret", value: secret), URLQueryItem(name: "issuer", value: issuer)]
        return url.url!
    }
    
    /// Generate QR code for compatible TOTP applications
    ///
    /// - Parameter url: URL for compatible TOTP applications
    /// - Returns: Image
    func generateQRCode(url: URL) -> NSImage? {
        let string = url.absoluteString
        let data = string.data(using: String.Encoding.ascii)
        
        if let filter = CIFilter(name: "CIQRCodeGenerator") {
            filter.setValue(data, forKey: "inputMessage")
            let transform = CGAffineTransform(scaleX: 5, y: 5)
            
            if let output = filter.outputImage?.transformed(by: transform) {
                let rep = NSCIImageRep(ciImage: output)
                let nsImage = NSImage(size: rep.size)
                nsImage.addRepresentation(rep)
                return nsImage
            }
        }
        return nil
    }
    
    /// Enroll user with TOTP 2FA at provider
    ///
    /// - Parameters:
    ///   - info: Provider info
    ///   - handler: Success or error
    func enrollTotp(for info: ProviderInfo, secret: String, otp: String, handler: @escaping (Result<Void>) -> ()) {
        let path: String = "two_factor_enroll_totp"
        
        guard let url = URL(string: path, relativeTo: info.apiBaseURL) else {
            handler(.failure(Error.invalidProviderInfo))
            return
        }
        
        authenticationService.performAction(for: info) { (accessToken, idToken, error) in
            guard let accessToken = accessToken else {
                handler(.failure(error ?? Error.missingToken))
                return
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = "totp_secret=\(secret)&totp_key=\(otp)".data(using: .utf8)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            
            self.performEnrollmentRequest(request, handler: handler)
        }
    }
    
    /// Performs enrollment request which is identical for both totp and yubico
    private func performEnrollmentRequest(_ request: URLRequest, handler: @escaping (Result<Void>) -> ()) {
        let task = self.urlSession.dataTask(with: request) { (data, response, error) in
            guard let data = data, let response = response as? HTTPURLResponse, 200..<300 ~= response.statusCode else {
                handler(.failure(error ?? Error.unknown))
                return
            }
            do {
                guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? NSDictionary else {
                    handler(.failure(Error.invalidTwoFactor))
                    return
                }
                
                guard let path = request.url?.lastPathComponent, let instance = json.value(forKeyPath: path) as? [String: AnyObject] else {
                    handler(.failure(Error.invalidTwoFactor))
                    return
                }
                
                guard let isOk = instance["ok"] as? Bool else {
                    handler(.failure(Error.invalidTwoFactor))
                    return
                }
                
                if isOk {
                    handler(.success(Void()))
                } else {
                    guard let error = instance["error"] as? String else {
                        handler(.failure(Error.invalidTwoFactor))
                        return
                    }
                    
                    switch error {
                    case "user already enrolled":
                        handler(.failure(Error.userAlreadyEnrolled))
                    default:
                        handler(.failure(Error.invalidTwoFactor))
                    }
                }
            } catch(let error) {
                handler(.failure(error))
                return
            }
        }
        task.resume()
    }
    
}
