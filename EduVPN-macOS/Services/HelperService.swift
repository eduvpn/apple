//
//  HelperService.swift
//  eduVPN
//
//  Created by Johan Kool on 06/07/2017.
//  Copyright © 2017-2019 Commons Conservancy.
//

import Foundation
import AppKit
import Security
import ServiceManagement

/// Installs and connects helper
class HelperService {
    
    static let helperVersion = "0.2-24"
    static let helperIdentifier = "org.eduvpn.app.openvpnhelper"

    enum Error: Swift.Error, LocalizedError {
        case noHelperConnection
        case authenticationFailed
        case installationFailed(ServiceManagementError)
        case connectionInvalidated
        case connectionInterrupted
        
        var errorDescription: String? {
            switch self {
            case .noHelperConnection:
                return NSLocalizedString("Installation failed", comment: "")
            case .authenticationFailed:
                return NSLocalizedString("Authentication failed", comment: "")
            case .installationFailed:
                return NSLocalizedString("Installation failed", comment: "")
            case .connectionInvalidated:
                return NSLocalizedString("Connection invalidated", comment: "")
            case .connectionInterrupted:
                return NSLocalizedString("Connection interrupted", comment: "")
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .noHelperConnection:
                return NSLocalizedString("Try reinstalling eduVPN.", comment: "")
            case .authenticationFailed, .connectionInvalidated, .connectionInterrupted:
                return NSLocalizedString("Try to connect again.", comment: "")
            case .installationFailed(let serviceManagementError):
                return (serviceManagementError.errorDescription ?? "") + " (SM-\(serviceManagementError.rawValue)) " + NSLocalizedString("Try reinstalling eduVPN.", comment: "")
            }
        }
    }

    enum ServiceManagementError: Int, Swift.Error, LocalizedError {
        case unknown = 0
        case helperVersionMismatch = 1
        case kSMErrorInternalFailure = 2
        case kSMErrorInvalidSignature = 3
        case kSMErrorAuthorizationFailure = 4
        case kSMErrorToolNotValid = 5
        case kSMErrorJobNotFound = 6
        case kSMErrorServiceUnavailable = 7
        case kSMErrorJobPlistNotFound = 8
        case kSMErrorJobMustBeEnabled = 9
        case kSMErrorInvalidPlist = 10
        
        var errorDescription: String? {
            switch self {
            case .unknown:
                return NSLocalizedString("An unknown error has occurred.", comment: "")
            case .helperVersionMismatch:
                return NSLocalizedString("The helper has an unexpected version.", comment: "")
            case .kSMErrorInternalFailure:
                return NSLocalizedString("An internal failure has occurred.", comment: "")
            case .kSMErrorInvalidSignature:
                return NSLocalizedString("The Application's code signature does not meet the requirements to perform the operation.", comment: "")
            case .kSMErrorAuthorizationFailure:
                return NSLocalizedString("The request required authorization (i.e. adding a job to the kSMDomainSystemLaunchd domain) but the AuthorizationRef did not contain the required right.", comment: "")
            case .kSMErrorToolNotValid:
                return NSLocalizedString("The specified path does not exist or the tool at the specified path is not valid.", comment: "")
            case .kSMErrorJobNotFound:
                return NSLocalizedString("A job with the given label could not be found.", comment: "")
            case .kSMErrorServiceUnavailable:
                return NSLocalizedString("The service required to perform this operation is unavailable or is no longer accepting requests.", comment: "")
            case .kSMErrorJobPlistNotFound:
                return NSLocalizedString("A plist for the job could not be found.", comment: "")
            case .kSMErrorJobMustBeEnabled:
                return NSLocalizedString("The job must be enabled.", comment: "")
            case .kSMErrorInvalidPlist:
                return NSLocalizedString("The plist was invalid.", comment: "")
            }
        }
    }

    private(set) var connection: NSXPCConnection?
    private var authRef: AuthorizationRef?
    
    // For reference: pass to helper?
    // private var authorization: Data!
    //    private func connectToAuthorization() {
    //        var authRef: AuthorizationRef?
    //        var err = AuthorizationCreate(nil, nil, [], &authRef)
    //        self.authRef = authRef
    //
    //        var form = AuthorizationExternalForm()
    //
    //        if (err == errAuthorizationSuccess) {
    //            err = AuthorizationMakeExternalForm(authRef!, &form);
    //        }
    //        if (err == errAuthorizationSuccess) {
    //            self.authorization = Data(bytes: &form.bytes, count: MemoryLayout.size(ofValue: form.bytes))
    //        }
    //    }
    
    /// Installs the helper if needed
    ///
    /// - Parameters:
    ///   - client: Client
    ///   - handler: Success or error
    func installHelperIfNeeded(client: ClientProtocol, handler: @escaping (Result<Void>) -> ()) {
        connectToHelper(client: client) { result in
            switch result {
            case .success(let upToDate):
                if upToDate {
                    handler(.success(Void()))
                    return
                }
            case .failure:
                break
            }
            
            self.installHelper { result in
                switch result {
                case .success:
                    self.connectToHelper(client: client) { result in
                        switch result {
                        case .success(let upToDate):
                            if upToDate {
                                handler(.success(Void()))
                            } else {
                                handler(.failure(Error.installationFailed(.helperVersionMismatch)))
                            }
                        case .failure(let error):
                            handler(.failure(error))
                        }
                    }
                case .failure(let error):
                    handler(.failure(error))
                }
            }
        }
    }
    
    /// Installs the helper
    ///
    /// - Parameter handler: Succes or error
    private func installHelper(_ handler: @escaping (Result<Void>) -> ()) {
        var status = AuthorizationCreate(nil, nil, AuthorizationFlags(), &authRef)
        guard status == errAuthorizationSuccess else {
            handler(.failure(Error.authenticationFailed))
            return
        }
        
        var item = AuthorizationItem(name: kSMRightBlessPrivilegedHelper, valueLength: 0, value: nil, flags: 0)
        var rights = AuthorizationRights(count: 1, items: &item)
        let flags = AuthorizationFlags([.interactionAllowed, .extendRights])
        
        status = AuthorizationCopyRights(authRef!, &rights, nil, flags, nil)
        guard status == errAuthorizationSuccess else {
            handler(.failure(Error.authenticationFailed))
            return
        }
        
        var error: Unmanaged<CFError>?
        let success = SMJobBless(
            kSMDomainSystemLaunchd,
            HelperService.helperIdentifier as CFString,
            authRef,
            &error
        )
        
        if success {
            handler(.success(Void()))
        } else {
            NSLog("SMJobBless failed: \(String(describing: error))")
            let code: Int
            if let error = error?.takeUnretainedValue() {
                code = CFErrorGetCode(error)
            } else {
                code = 0
            }
            let error = Error.installationFailed(ServiceManagementError(rawValue: code) ?? .unknown)
            NSLog("Installation failed: \(String(describing: error))")
            handler(.failure(error))
        }
    }
    
    /// Sets up a connection with the helper
    ///
    /// - Parameters:
    ///   - client: Client
    ///   - handler: True if up-to-date, false is older version or eror
    private func connectToHelper(client: ClientProtocol, handler: @escaping (Result<Bool>) -> ()) {
        connection = NSXPCConnection(machServiceName: HelperService.helperIdentifier, options: .privileged)
        let remoteObjectInterface = NSXPCInterface(with: OpenVPNHelperProtocol.self)
        connection?.remoteObjectInterface = remoteObjectInterface
        connection?.exportedInterface = NSXPCInterface(with: ClientProtocol.self)
        connection?.exportedObject = client
        connection?.invalidationHandler = { () in
            // Don't do this: handler(.failure(Error.connectionInvalidated))
            // It causes the helper to fail to install (somehow)
        }
        connection?.interruptionHandler = { () in
            // Don't do this: handler(.failure(Error.connectionInterrupted))
            // It causes the helper to fail to install (somehow)
        }
        connection?.resume()
        
        getHelperVersion { (result) in
            switch result {
            case .success(let version):
                handler(.success(version == HelperService.helperVersion))
            case .failure(let error):
                handler(.failure(error))
            }
        }
    }
    
    /// Ask the helper for its version
    ///
    /// - Parameter handler: Version or error
    private func getHelperVersion(_ handler: @escaping (Result<String>) -> ()) {
        guard let helper = connection?.remoteObjectProxyWithErrorHandler({ error in
            handler(.failure(error))
        }) as? OpenVPNHelperProtocol else {
            handler(.failure(Error.noHelperConnection))
            return
        }
        
        helper.getVersionWithReply() { (version) in
            handler(.success(version))
        }
       
        // Timeout workaround because reply not received, but disabled because it caused other installation issues
//        var handled = false
//        
//        let deadlineTime = DispatchTime.now() + .seconds(5)
//        DispatchQueue.main.asyncAfter(deadline: deadlineTime) {
//            if handled {
//                // Do nothing
//            } else {
//                handled = true
//                handler(.failure(Error.noHelperConnection))
//            }
//        }
//        
//        helper.getVersionWithReply() { (version) in
//            if handled {
//                // Do nothing
//                NSLog("Getting version took longer than 5 seconds!")
//            } else {
//                handled = true
//                handler(.success(version))
//            }
//        }
    }

}
