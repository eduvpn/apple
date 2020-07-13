//
//  PersistenceService.swift
//  EduVPN
//

import Foundation
import AppAuth
import PromiseKit
import os.log

class PersistenceService {

    fileprivate struct AddedServers {
        var simpleServers: [SimpleServerInstance]
        var secureInternetServer: SecureInternetServerInstance?

        init() {
            simpleServers = []
            secureInternetServer = nil
        }
    }

    private var addedServers: AddedServers

    var simpleServers: [SimpleServerInstance] {
        addedServers.simpleServers
    }

    var secureInternetServer: SecureInternetServerInstance? {
        addedServers.secureInternetServer
    }

    var hasServers: Bool {
        addedServers.secureInternetServer != nil || !addedServers.simpleServers.isEmpty
    }

    init() {
        addedServers = Self.loadFromFile() ?? AddedServers()
    }

    func addSimpleServer(_ server: SimpleServerInstance) {
        let baseURLString = server.baseURLString
        addedServers.simpleServers.removeAll {
            $0.baseURLString == baseURLString
        }
        addedServers.simpleServers.append(server)
        Self.saveToFile(addedServers: addedServers)
    }

    func removeSimpleServer(_ server: SimpleServerInstance) {
        let baseURLString = server.baseURLString
        let pivotIndex = addedServers.simpleServers.partition(
            by: { $0.baseURLString == baseURLString })
        for index in pivotIndex ..< addedServers.simpleServers.count {
            DataStore(path: addedServers.simpleServers[index].localStoragePath).delete()
        }
        addedServers.simpleServers.removeLast(addedServers.simpleServers.count - pivotIndex)
        Self.saveToFile(addedServers: addedServers)
    }

    func setSecureInternetServer(_ server: SecureInternetServerInstance) {
        if let existingServer = addedServers.secureInternetServer {
            DataStore(path: existingServer.localStoragePath).delete()
        }
        addedServers.secureInternetServer = server
        Self.saveToFile(addedServers: addedServers)
    }

    func setSecureInternetServerAPIBaseURLString(_ urlString: DiscoveryData.BaseURLString) {
        guard let existingServer = addedServers.secureInternetServer else {
            os_log("No secure internet server exists", log: Log.general, type: .error)
            return
        }
        if urlString == existingServer.apiBaseURLString {
            return
        }
        // Remove client certificate data here
        let server = SecureInternetServerInstance(
            apiBaseURLString: urlString, authBaseURLString: existingServer.authBaseURLString,
            orgId: existingServer.orgId, localStoragePath: existingServer.localStoragePath)
        addedServers.secureInternetServer = server
        Self.saveToFile(addedServers: addedServers)
    }

    func removeSecureInternetServer() {
        if let existingServer = addedServers.secureInternetServer {
            DataStore(path: existingServer.localStoragePath).delete()
        }
        addedServers.secureInternetServer = nil
        Self.saveToFile(addedServers: addedServers)
    }

    private static func loadFromFile() -> AddedServers? {
        if let data = try? Data(contentsOf: Self.jsonStoreURL) {
            return try? JSONDecoder().decode(AddedServers.self, from: data)
        }
        return nil
    }

    private static func saveToFile(addedServers: AddedServers) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(addedServers) {
            PersistenceService.write(data, to: Self.jsonStoreURL, atomically: true)
        }
    }
}

extension PersistenceService {
    private static var rootURL: URL {
        guard let applicationSupportDirURL = FileHelper.applicationSupportDirectoryUrl() else {
            fatalError("Can't find application support directory")
        }
        let url = applicationSupportDirURL.appendingPathComponent("AddedServers")
        PersistenceService.ensureDirectoryExists(at: url)
        return url
    }

    private static var jsonStoreURL: URL {
        return rootURL
            .appendingPathComponent("added_servers.json")
    }
}

extension PersistenceService {
    class DataStore: NSObject {
        let rootURL: URL

        init(path: String) {
            let rootURL = PersistenceService.rootURL.appendingPathComponent(path)
            PersistenceService.ensureDirectoryExists(at: rootURL)
            self.rootURL = rootURL
        }

        private var authStateURL: URL {
            rootURL.appendingPathComponent("authState.bin")
        }

        private var keyPairURL: URL {
            rootURL.appendingPathComponent("keyPair.bin")
        }

        var authState: AuthState? {
            get {
                if let data = try? Data(contentsOf: authStateURL),
                    let clearTextData = Crypto.shared.decrypt(data: data),
                    let oidAuthState = try? NSKeyedUnarchiver.unarchivedObject(ofClass: OIDAuthState.self, from: clearTextData) {
                    return AuthState(oidAuthState: oidAuthState)
                }
                return nil
            }
            set(value) {
                if let oidAuthState = value?.oidAuthState,
                    let data = try? NSKeyedArchiver.archivedData(withRootObject: oidAuthState, requiringSecureCoding: false),
                    let encryptedData = try? Crypto.shared.encrypt(data: data) {
                    PersistenceService.write(encryptedData, to: authStateURL, atomically: true)
                } else {
                    removeAuthState()
                }
            }
        }

        var keyPair: CreateKeyPairResponse.KeyPair? {
            get {
                if let data = try? Data(contentsOf: keyPairURL),
                    let clearTextData = Crypto.shared.decrypt(data: data) {
                    return try? JSONDecoder().decode(CreateKeyPairResponse.KeyPair.self, from: clearTextData)
                }
                return nil
            }
            set(value) {
                if let data = try? JSONEncoder().encode(value),
                    let encryptedData = try? Crypto.shared.encrypt(data: data) {
                    PersistenceService.write(encryptedData, to: keyPairURL, atomically: true)
                }
            }
        }

        func removeAuthState() {
            PersistenceService.removeItemAt(url: authStateURL)
        }

        func delete() {
            PersistenceService.removeItemAt(url: rootURL)
        }

    }
}

extension PersistenceService {
    private static func ensureDirectoryExists(at url: URL) {
        do {
            try FileManager.default.createDirectory(at: url,
                                                withIntermediateDirectories: true,
                                                attributes: nil)
        } catch {
            os_log("Error creating URL '%{public}@': %{public}@",
                   log: Log.general, type: .error,
                   url.absoluteString, error.localizedDescription)
        }
    }

    private static func removeItemAt(url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            os_log("Error removing URL '%{public}@': %{public}@",
                   log: Log.general, type: .error,
                   url.absoluteString, error.localizedDescription)
        }
    }

    private static func write(_ data: Data, to url: URL, atomically: Bool) {
        do {
            try data.write(to: url, options: atomically ? [.atomic] : [])
        } catch {
            os_log("Error writing data %{public}@to URL '%{public}@': %{public}@",
                   log: Log.general, type: .error,
                   (atomically ? "atomically " : ""),
                   url.absoluteString, error.localizedDescription)
        }
    }
}

extension PersistenceService.AddedServers: Codable {
    enum CodingKeys: String, CodingKey {
        case simpleServers = "simple_servers"
        case secureInternetServer = "secure_internet_server"
    }
}

extension PersistenceService.DataStore: OIDAuthStateChangeDelegate {
    func didChange(_ state: OIDAuthState) {
        authState = AuthState(oidAuthState: state)
    }
}
