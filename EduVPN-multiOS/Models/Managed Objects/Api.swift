//
//  Api.swift
//  eduVPN
//

import Foundation
import CoreData
import AppAuth
import UserNotifications
import os.log

extension Api {
    
    static func upsert(with instanceInfoModel: InstanceInfoModel,
                       for instance: Instance,
                       on context: NSManagedObjectContext) -> Api {
        
        let api: Api
        let instance = context.object(with: instance.objectID) as? Instance
        if let instance = instance, let baseUri = instance.baseUri {
            let predicate = NSPredicate(format: "instance.baseUri == %@ AND apiBaseUri == %@",
                                        baseUri, instanceInfoModel.apiBaseUrl.absoluteString)
            
            api = try! Api.findFirstInContext(context, predicate: predicate) ?? Api(context: context) //swiftlint:disable:this force_try
        } else {
            api = Api(context: context)
        }
        
        instance?.authServer = AuthServer.upsert(with: instanceInfoModel, on: context)
        
        api.instance = instance
        api.apiBaseUri = instanceInfoModel.apiBaseUrl.absoluteString
        
        return api
    }
    
    var authorizationEndpoint: String? {
        guard let authorizationType = instance?.group?.authorizationTypeEnum else { return authServer?.authorizationEndpoint }
        
        switch authorizationType {
        case .local:
            return authServer?.authorizationEndpoint
        case .federated:
            return instance?.authServer?.authorizationEndpoint
        case .distributed:
            return instance?.authServer?.authorizationEndpoint ?? authServer?.authorizationEndpoint
        }
    }
    
    var tokenEndpoint: String? {
        guard let authorizationType = instance?.group?.authorizationTypeEnum else { return authServer?.tokenEndpoint }
        
        switch authorizationType {
        case .local:
            return authServer?.tokenEndpoint
        case .federated:
            return instance?.authServer?.tokenEndpoint
        case .distributed:
            return instance?.authServer?.tokenEndpoint ?? authServer?.tokenEndpoint
        }
    }
    
    private var authStateUrl: URL? {
        guard let authStateUrl = authorizationEndpointFileUrl else { return nil }
        return authStateUrl.appendingPathComponent("authState.bin")
    }
    
    private var certificateUrl: URL? {
        guard var certificateUrl = apiBaseFileUrl else { return nil }
        certificateUrl.appendPathComponent("client.certificate")
        return certificateUrl
    }
    
    private var apiBaseFileUrl: URL? {
        guard let apiBaseUri = apiBaseUri, let apiBaseUriUrl = URL(string: apiBaseUri) else { return nil }
        return FileHelper.filePathUrl(from: apiBaseUriUrl)
    }
    
    private var authorizationEndpointFileUrl: URL? {
        guard let authorizationEndpoint = authorizationEndpoint, let authorizationEndpointUrl = URL(string: authorizationEndpoint) else { return nil }
        return FileHelper.filePathUrl(from: authorizationEndpointUrl)
    }
    
    var authState: OIDAuthState? {
        get {
            guard let authStateUrl = authStateUrl else { return nil }
            if FileManager.default.fileExists(atPath: authStateUrl.path) {
                do {
                    let data = try Data(contentsOf: authStateUrl)
                    if let clearTextData = Crypto.shared.decrypt(data: data) {
                        return try NSKeyedUnarchiver.unarchivedObject(ofClass: OIDAuthState.self, from: clearTextData)
                    }
                } catch {
                    os_log("Failed load Authstate. %{public}@", log: Log.crypto, type: .error, error.localizedDescription)
                    return nil
                }
            }
            
            return nil
        }
        set {
            guard let authStateUrl = authStateUrl else { return }
            if let newValue = newValue {
                do {
                    let data = try NSKeyedArchiver.archivedData(withRootObject: newValue, requiringSecureCoding: false)
                    
                    #if os(iOS)
                    let options: Data.WritingOptions = [.atomicWrite, .completeFileProtectionUntilFirstUserAuthentication]
                    #elseif os(macOS)
                    let options: Data.WritingOptions = []
                    #endif
                    
                    let encryptedData = try Crypto.shared.encrypt(data: data)
                    try encryptedData?.write(to: authStateUrl, options: options)
                    
                    excludeFromBackup(url: authStateUrl)
                } catch {
                    os_log("Failed to write Authstate %{public}@", log: Log.crypto, type: .error, error.localizedDescription)
                }
            } else {
                try? FileManager.default.removeItem(at: authStateUrl)
            }
        }
    }
    
    var certificateModel: CertificateModel? {
        get {
            guard let certificateUrl = certificateUrl else { return nil }
            if FileManager.default.fileExists(atPath: certificateUrl.path) {
                do {
                    let data = try Data(contentsOf: certificateUrl)
                    if let clearTextData = Crypto.shared.decrypt(data: data) {
                        return try JSONDecoder().decode(CertificateModel.self, from: clearTextData)
                    }
                } catch {
                    os_log("Failed load certificate model. %{public}@", log: Log.crypto, type: .error, error.localizedDescription)
                    return nil
                }
            }
            
            return nil
        }
        set {
            guard let certificateUrl = certificateUrl else { return }
            if let oldIdentifier = certificateModel?.uniqueIdentifier {
                if oldIdentifier != newValue?.uniqueIdentifier ?? "" {
                    #if os(iOS)
                    UNUserNotificationCenter.current()
                        .removePendingNotificationRequests(withIdentifiers: [oldIdentifier])
                    #elseif os(macOS)
                    if #available(OSX 10.14, *) {
                        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [oldIdentifier])
                    }
                    #endif
                }
            }
            
            if let newValue = newValue {
                do {
                    let data = try JSONEncoder().encode(newValue)
                    
                    #if os(iOS)
                    let options: Data.WritingOptions = [Data.WritingOptions.atomicWrite,
                                                        .completeFileProtectionUntilFirstUserAuthentication]
                    #elseif os(macOS)
                    let options: Data.WritingOptions = []
                    #endif
                    
                    let encryptedData = try Crypto.shared.encrypt(data: data)
                    try encryptedData?.write(to: certificateUrl, options: options)
                    
                    excludeFromBackup(url: certificateUrl)
                } catch {
                    os_log("Failed to write certificate model %{public}@", log: Log.crypto, type: .error, error.localizedDescription)
                }
            } else {
                try? FileManager.default.removeItem(at: certificateUrl)
            }
        }
    }
    
    private func excludeFromBackup(url: URL) {
        var url = url
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try? url.setResourceValues(resourceValues)
    }
    
}
