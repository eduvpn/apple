//
//  PersistenceService.swift
//  EduVPN
//

import Foundation
import AppAuth
import PromiseKit
import os.log

protocol PersistenceServiceHasServersDelegate: class {
    func persistenceService(_ persistenceService: PersistenceService,
                            hasServersChangedTo hasServers: Bool)
}

class PersistenceService {

    fileprivate struct AddedServers {
        var simpleServers: [SimpleServerInstance]
        var secureInternetServer: SecureInternetServerInstance?
        var serversMigratedBasedOnFilePathURL: [String]
        var openVPNConfigs: [OpenVPNConfigInstance]?

        init() {
            simpleServers = []
            secureInternetServer = nil
            serversMigratedBasedOnFilePathURL = []
            openVPNConfigs = []
        }

        init(migrateFromFilePathURL servers: [SimpleServerInstance]) {
            simpleServers = servers
            secureInternetServer = nil
            serversMigratedBasedOnFilePathURL = servers.map { $0.baseURLString.urlString }
            openVPNConfigs = []
        }
    }

    private var addedServers: AddedServers

    var simpleServers: [SimpleServerInstance] {
        addedServers.simpleServers
    }

    var secureInternetServer: SecureInternetServerInstance? {
        addedServers.secureInternetServer
    }

    var openVPNConfigs: [OpenVPNConfigInstance]? {
        addedServers.openVPNConfigs
    }

    var hasServers: Bool = false

    weak var hasServersDelegate: PersistenceServiceHasServersDelegate?

    init() {
        if ProcessInfo.processInfo.isUITestingFreshInstall {
            addedServers = AddedServers()
            removeLastConnectionAttempt()
            return
        }
        
        if ProcessInfo.processInfo.isUITestingConfigured {
            addedServers = AddedServers()
            removeLastConnectionAttempt()
            addSimpleServer(SimpleServerInstance(baseURLString: DiscoveryData.BaseURLString(urlString: "https://demo.eduvpn.nl/"), localStoragePath: UUID().uuidString))
            return
        }
        
        if Self.isJSONStoreExists() {
            addedServers = Self.loadFromFile() ?? AddedServers()
        } else {
            addedServers = AddedServers(migrateFromFilePathURL: MigrationHelper.migrateServersFromFilePathURL())
            Self.saveToFile(addedServers: addedServers)
        }
        updateHasServers()
    }

    func addSimpleServer(_ server: SimpleServerInstance) {
        let baseURLString = server.baseURLString
        addedServers.simpleServers.removeAll {
            $0.baseURLString == baseURLString
        }
        addedServers.simpleServers.append(server)
        Self.saveToFile(addedServers: addedServers)
        updateHasServers()
    }

    func removeSimpleServer(_ server: SimpleServerInstance) {
        let baseURLString = server.baseURLString
        let pivotIndex = addedServers.simpleServers.partition(
            by: { $0.baseURLString == baseURLString })
        for index in pivotIndex ..< addedServers.simpleServers.count {
            DataStore(path: addedServers.simpleServers[index].localStoragePath).delete()
        }
        addedServers.simpleServers.removeLast(addedServers.simpleServers.count - pivotIndex)
        addedServers.serversMigratedBasedOnFilePathURL.removeAll(where: { $0 == baseURLString.urlString })
        Self.saveToFile(addedServers: addedServers)
        updateHasServers()
    }

    func setSecureInternetServer(_ server: SecureInternetServerInstance) {
        if let existingServer = addedServers.secureInternetServer {
            DataStore(path: existingServer.localStoragePath).delete()
        }
        addedServers.secureInternetServer = server
        Self.saveToFile(addedServers: addedServers)
        updateHasServers()
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
        updateHasServers()
    }

    func removeSecureInternetServer() {
        if let existingServer = addedServers.secureInternetServer {
            DataStore(path: existingServer.localStoragePath).delete()
        }
        addedServers.secureInternetServer = nil
        Self.saveToFile(addedServers: addedServers)
    }

    func addOpenVPNConfiguration(_ instance: OpenVPNConfigInstance) {
        if addedServers.openVPNConfigs == nil {
            addedServers.openVPNConfigs = []
        }
        addedServers.openVPNConfigs?.append(instance)
        Self.saveToFile(addedServers: addedServers)
        updateHasServers()
    }

    func removeOpenVPNConfiguration(_ instance: OpenVPNConfigInstance) {
        let existingIndex = addedServers.openVPNConfigs?.firstIndex(
            where: { $0.localStoragePath == instance.localStoragePath })
        if let existingIndex = existingIndex {
            DataStore(path: instance.localStoragePath).delete()
            addedServers.openVPNConfigs?.remove(at: existingIndex)
            if let openVPNConfigs = addedServers.openVPNConfigs, openVPNConfigs.isEmpty {
                addedServers.openVPNConfigs = nil
            }
            Self.saveToFile(addedServers: addedServers)
            updateHasServers()
        }
    }

    static func isJSONStoreExists() -> Bool {
        FileManager.default.fileExists(atPath: jsonStoreURL.path)
    }

    private static func loadFromFile() -> AddedServers? {
        if let data = try? Data(contentsOf: Self.jsonStoreURL) {
            do {
                return try JSONDecoder().decode(AddedServers.self, from: data)
            } catch {
                print("Error: \(error)")
                return nil
            }
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

    private func updateHasServers() {
        let value = addedServers.secureInternetServer != nil ||
            !addedServers.simpleServers.isEmpty ||
            !(addedServers.openVPNConfigs ?? []).isEmpty
        if hasServers != value {
            hasServers = value
            hasServersDelegate?.persistenceService(self, hasServersChangedTo: value)
        }
    }


}

extension PersistenceService {
    func loadLastConnectionAttempt() -> ConnectionAttempt? {
        if let data = try? Data(contentsOf: Self.lastConnectionAttemptURL) {
            do {
                return try JSONDecoder().decode(ConnectionAttempt.self, from: data)
            } catch {
                os_log("Error decoding last_connection_attempt.json: %{public}@",
                       log: Log.general, type: .error, error.localizedDescription)
            }
        }
        return nil
    }

    func removeLastConnectionAttempt() {
        PersistenceService.removeItemAt(url: Self.lastConnectionAttemptURL)
    }

    func saveLastConnectionAttempt(_ connectionAttempt: ConnectionAttempt) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(connectionAttempt) {
            PersistenceService.write(data, to: Self.lastConnectionAttemptURL, atomically: true)
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

    private static var lastConnectionAttemptURL: URL {
        return rootURL
            .appendingPathComponent("last_connection_attempt.json")
    }
}

extension PersistenceService {
    class DataStore {
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

        private var migratedClientCertificateURL: URL {
            rootURL.appendingPathComponent("client.certificate")
        }

        private var selectedProfileURL: URL {
            rootURL.appendingPathComponent("selected_profile.json")
        }

        private var vpnConfigURL: URL {
            rootURL.appendingPathComponent("vpn_config")
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
                if let data = try? Data(contentsOf: migratedClientCertificateURL),
                    let clearTextData = Crypto.shared.decrypt(data: data) {
                    let response = try? JSONDecoder().decode(CreateKeyPairResponse.self, from: clearTextData)
                    return response?.data
                }
                return nil
            }
            set(value) {
                if let data = try? JSONEncoder().encode(value),
                    let encryptedData = try? Crypto.shared.encrypt(data: data) {
                    PersistenceService.write(encryptedData, to: keyPairURL, atomically: true)
                }
                if FileManager.default.fileExists(atPath: migratedClientCertificateURL.path) {
                    try? FileManager.default.removeItem(at: migratedClientCertificateURL)
                }
            }
        }

        var vpnConfig: String? {
            get {
                if let data = try? Data(contentsOf: vpnConfigURL) {
                    return String(data: data, encoding: .utf8)
                }
                return nil
            }
            set(value) {
                let data = value?.data(using: .utf8) ?? Data()
                PersistenceService.write(data, to: vpnConfigURL, atomically: true)
            }
        }

        private func getSelectedProfileIdMap() -> [String: String]? {
            if let data = try? Data(contentsOf: selectedProfileURL) {
                return try? JSONDecoder().decode([String: String].self, from: data)
            }
            return nil
        }

        func selectedProfileId(for apiBaseURLString: DiscoveryData.BaseURLString) -> String? {
            let map = getSelectedProfileIdMap()
            return map?[apiBaseURLString.urlString]
        }

        func setSelectedProfileId(profileId: String?, for apiBaseURLString: DiscoveryData.BaseURLString) {
            var map = getSelectedProfileIdMap() ?? [:]
            if map[apiBaseURLString.urlString] != profileId {
                if let profileId = profileId {
                    map[apiBaseURLString.urlString] = profileId
                } else {
                    map.removeValue(forKey: apiBaseURLString.urlString)
                }
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                if let data = try? encoder.encode(map) {
                    PersistenceService.write(data, to: selectedProfileURL, atomically: true)
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
        guard FileManager.default.fileExists(atPath: url.path) else {
            return
        }
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
        case serversMigratedBasedOnFilePathURL = "servers_migrated_based_on_file_path_url"
        case openVPNConfigs = "ovpn_configs"
    }
}
