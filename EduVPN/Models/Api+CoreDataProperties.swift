//
//  Api+CoreDataProperties.swift
//  eduVPN
//
//  Created by Jeroen Leenarts on 04-02-18.
//  Copyright © 2018 SURFNet. All rights reserved.
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

    private func filePathUrl(from url: URL) -> URL? {
        guard var fileUrl = try? FileManager.default.url(for: .applicationSupportDirectory,
                                                         in: .userDomainMask,
                                                         appropriateFor: nil,
                                                         create: false) else { return nil }

        if let host = url.host {
            fileUrl.appendPathComponent(host)
            try? FileManager.default.createDirectory(at: fileUrl, withIntermediateDirectories: true, attributes: [FileAttributeKey.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
        }

        if !url.path.isEmpty {
            fileUrl.appendPathComponent(url.path)
            try? FileManager.default.createDirectory(at: fileUrl, withIntermediateDirectories: true, attributes: [FileAttributeKey.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
        }

        return fileUrl
    }

    var authState: OIDAuthState? {
        get {
            guard let authStateUrl = authStateUrl else { return nil }
            if FileManager.default.fileExists(atPath: authStateUrl.path) {
                if let data = try? Data(contentsOf: authStateUrl), let clearTextData = Crypto.decrypt(data: data) {
                    return NSKeyedUnarchiver.unarchiveObject(with: clearTextData) as? OIDAuthState
                }
            }

            return nil
        }
        set {
            guard let authStateUrl = authStateUrl else { return }
            if let newValue = newValue {
                let data = NSKeyedArchiver.archivedData(withRootObject: newValue)
                do {
                    let encryptedData = try Crypto.encrypt(data: data)
                    try encryptedData?.write(to: authStateUrl, options: [.atomicWrite, .completeFileProtectionUntilFirstUserAuthentication])

                    excludeFromBackup(url: authStateUrl)
                } catch {
                    os_log("Failed to fetch objects: %{public}@", log: Log.crypto, type: .error, error.localizedDescription)
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
                if let data = try? Data(contentsOf: certificateUrl) {
                    do {
                        return try JSONDecoder().decode(CertificateModel.self, from: data)
                    } catch {
                        return nil
                    }
                }
            }

            return nil
        }
        set {
            guard let certificateUrl = certificateUrl else { return }
            if let oldIdentifier = certificateModel?.uniqueIdentifier {
                if oldIdentifier != newValue?.uniqueIdentifier ?? "" {
                    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [oldIdentifier])
                }
            }

            if let newValue = newValue {
                let data = try? JSONEncoder().encode(newValue)
                try? data?.write(to: certificateUrl, options: [Data.WritingOptions.atomicWrite, .completeFileProtectionUntilFirstUserAuthentication])

                excludeFromBackup(url: certificateUrl)
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
