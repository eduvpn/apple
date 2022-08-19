//
//  AppDataRemover.swift
//  EduVPN
//

import Foundation
import CoreData

class AppDataRemover {
    static func removeAllData(persistenceService: PersistenceService?) {
        persistenceService?.removeAllData()
        removeLegacyData()
        clearCaches()
        resetPreferences()
    }

    static func clearCaches() {
        DiscoveryDataFetcher.diskCache.removeAllCachedResponses()
        URLCache.shared.removeAllCachedResponses()
    }

    static func resetPreferences() {
        UserDefaults.standard.clearPreferences()
    }

    static func removeLegacyData() {
        let coreDataDbURL = NSPersistentContainer.defaultDirectoryURL()
        removeContentsOfDirectory(at: coreDataDbURL, where: { url in
            url.isFileURL && url.pathExtension.starts(with: "sqlite")
        })

        if let appSupportURL = FileHelper.applicationSupportDirectoryUrl() {
            removeContentsOfDirectory(at: appSupportURL, where: { url in
                url.lastPathComponent != "AddedServers"
            })
        }
    }

    private static func removeContentsOfDirectory(at directoryURL: URL, where condition: (URL) -> Bool) {
        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(
            at: directoryURL, includingPropertiesForKeys: nil,
            options: [.skipsSubdirectoryDescendants])
        while let url = enumerator?.nextObject() as? URL {
            if condition(url) {
                try? fileManager.removeItem(at: url)
            }
        }
    }
}
