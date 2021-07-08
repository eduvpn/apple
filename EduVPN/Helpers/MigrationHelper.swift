//
//  MigrationHelper.swift
//  EduVPN
//

import Foundation
import os.log

class MigrationHelper {
    static func migrateServersFromFilePathURL() -> [SimpleServerInstance] {
        let fileManager = FileManager.default
        guard let applicationSupportDirURL = FileHelper.applicationSupportDirectoryUrl() else {
            return []
        }

        let secureInternetServersMap = secureInternetServersFromIncludedServerList()

        guard let dirEntries = try? fileManager.contentsOfDirectory(
            at: applicationSupportDirURL,
            includingPropertiesForKeys: [URLResourceKey.isDirectoryKey],
            options: []) else {
                return []
        }

        var migratedServers: [SimpleServerInstance] = []

        for dirEntry in dirEntries {

            let dirName = dirEntry.lastPathComponent

            guard let resourceValues = try? dirEntry.resourceValues(forKeys: Set([URLResourceKey.isDirectoryKey])),
                let isDirectory = resourceValues.isDirectory, isDirectory else {
                    continue
            }

            if dirName == "AddedServers" {
                continue
            }

            let urlString = "https://\(dirName)/"

            if secureInternetServersMap[DiscoveryData.BaseURLString(urlString: urlString)] != nil {
                // We cannot migrate secure internet servers to the new discovery scheme
                // because there was previously no organization associated with
                // a secure internet server.
                os_log("Not migrating secure internet server \"%{public}@\"",
                       log: Log.general, type: .debug, urlString)
                continue
            }

            let storagePath = UUID().uuidString
            let dataStoreURL = PersistenceService.DataStore(path: storagePath).rootURL
            let server = SimpleServerInstance(
                baseURLString: DiscoveryData.BaseURLString(urlString: urlString),
                localStoragePath: storagePath)

            guard let dirEnumerator = fileManager.enumerator(
                at: dirEntry,
                includingPropertiesForKeys: [URLResourceKey.isRegularFileKey],
                options: []) else {
                    return []
            }

            for case let fileURL as URL in dirEnumerator {
                guard let resourceValues = try? fileURL.resourceValues(forKeys: Set([URLResourceKey.isRegularFileKey])),
                    let isRegularFile = resourceValues.isRegularFile, isRegularFile
                    else {
                        continue
                }
                let fileName = fileURL.lastPathComponent
                if fileName == "authState.bin" || fileName == "client.certificate" {
                    try? fileManager.copyItem(at: fileURL, to: dataStoreURL.appendingPathComponent(fileName))
                }
            }

            migratedServers.append(server)

        }

        return migratedServers
    }

    private static func secureInternetServersFromIncludedServerList() -> [DiscoveryData.BaseURLString: DiscoveryData.SecureInternetServer] {
        guard let includedServerListURL = Bundle.main.url(forResource: "server_list", withExtension: "json"),
            let data = try? Data(contentsOf: includedServerListURL),
            let servers = try? JSONDecoder().decode(DiscoveryData.Servers.self, from: data) else {
                return [:]
        }
        return servers.secureInternetServersMap
    }
}
