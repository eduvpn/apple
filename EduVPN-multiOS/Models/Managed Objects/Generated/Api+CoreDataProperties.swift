//
//  Api+CoreDataProperties.swift
//  eduVPN
//
//

import Foundation
import CoreData

import AppAuth
import UserNotifications

import os.log

extension Api {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Api> {
        return NSFetchRequest<Api>(entityName: "Api")
    }
    
    @NSManaged public var apiBaseUri: String?
    @NSManaged public var instance: Instance?
    @NSManaged public var profiles: Set<Profile>
    @NSManaged public var authServer: AuthServer?
    
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
        return filePathUrl(from: apiBaseUriUrl)
    }
    
    private var authorizationEndpointFileUrl: URL? {
        guard let authorizationEndpoint = authorizationEndpoint, let authorizationEndpointUrl = URL(string: authorizationEndpoint) else { return nil }
        return filePathUrl(from: authorizationEndpointUrl)
    }
    
    var authState: OIDAuthState? {
        get {
            guard let authStateUrl = authStateUrl else { return nil }
            if FileManager.default.fileExists(atPath: authStateUrl.path) {
                do {
                    let data = try Data(contentsOf: authStateUrl)
                    if let clearTextData = Crypto.shared.decrypt(data: data) {
                        let authState = try NSKeyedUnarchiver.unarchivedObject(ofClass: OIDAuthState.self, from: clearTextData)
                        authState?.stateChangeDelegate = self
                        return authState
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
                    newValue.stateChangeDelegate = self
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

extension Api: OIDAuthStateChangeDelegate {
    public func didChange(_ state: OIDAuthState) {
        self.authState = state
    }
}

// MARK: Generated accessors for profiles
extension Api {
    
    @objc(addProfilesObject:)
    @NSManaged public func addToProfiles(_ value: Profile)
    
    @objc(removeProfilesObject:)
    @NSManaged public func removeFromProfiles(_ value: Profile)
    
    @objc(addProfiles:)
    @NSManaged public func addToProfiles(_ values: NSSet)
    
    @objc(removeProfiles:)
    @NSManaged public func removeFromProfiles(_ values: NSSet)
    
}
