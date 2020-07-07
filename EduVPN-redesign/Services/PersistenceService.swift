//
//  PersistenceService.swift
//  EduVPN
//

import Foundation
import AppAuth
import PromiseKit

class PersistenceService {

    typealias BaseURLString = String

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
        let baseURLString = server.baseURL.absoluteString
        addedServers.simpleServers.removeAll {
            $0.baseURL.absoluteString == baseURLString
        }
        addedServers.simpleServers.append(server)
        Self.saveToFile(addedServers: addedServers)
    }

    func removeSimpleServer(_ server: SimpleServerInstance) {
        let baseURLString = server.baseURL.absoluteString
        let pivotIndex = addedServers.simpleServers.partition(
            by: { $0.baseURL.absoluteString == baseURLString })
        for index in pivotIndex ..< addedServers.simpleServers.count {
            ServerDataStore(path: addedServers.simpleServers[index].localStoragePath).delete()
        }
        addedServers.simpleServers.removeLast(addedServers.simpleServers.count - pivotIndex)
        Self.saveToFile(addedServers: addedServers)
    }

    func setSecureInternetServer(_ server: SecureInternetServerInstance) {
        if let existingServer = addedServers.secureInternetServer {
            ServerDataStore(path: existingServer.localStoragePath).delete()
        }
        addedServers.secureInternetServer = server
        Self.saveToFile(addedServers: addedServers)
    }

    func setSecureInternetServerAPIBaseURL(_ url: URL) {
        guard let existingServer = addedServers.secureInternetServer else {
            NSLog("No secure internet server exists")
            return
        }
        if url == existingServer.apiBaseURL {
            return
        }
        // Remove client certificate data here
        let server = SecureInternetServerInstance(
            apiBaseURL: url, authBaseURL: existingServer.authBaseURL,
            orgId: existingServer.orgId, localStoragePath: existingServer.localStoragePath)
        addedServers.secureInternetServer = server
        Self.saveToFile(addedServers: addedServers)
    }

    func removeSecureInternetServer() {
        if let existingServer = addedServers.secureInternetServer {
            ServerDataStore(path: existingServer.localStoragePath).delete()
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
    class ServerDataStore {
        let rootURL: URL

        init(path: String) {
            let rootURL = PersistenceService.rootURL.appendingPathComponent(path)
            PersistenceService.ensureDirectoryExists(at: rootURL)
            self.rootURL = rootURL
        }

        private var authStateURL: URL {
            rootURL.appendingPathComponent("authState.bin")
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
            NSLog("Error creating \(url): \(error)")
        }
    }

    private static func removeItemAt(url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            NSLog("Error removing \(url): \(error)")
        }
    }

    private static func write(_ data: Data, to url: URL, atomically: Bool) {
        do {
            try data.write(to: url, options: atomically ? [.atomic] : [])
        } catch {
            NSLog("Error writing data \(atomically ? "atomically " : "")to \(url): \(error)")
        }
    }
}

extension PersistenceService.AddedServers: Codable {
    enum CodingKeys: String, CodingKey {
        case simpleServers = "simple_servers"
        case secureInternetServer = "secure_internet_server"
    }
}
