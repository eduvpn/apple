//
//  OpenVPNConfigImportHelper.swift
//  EduVPN
//

import Foundation
import TunnelKit

enum OpenVPNConfigImportHelperError: Error {
    case openVPNConfigUnreadable
    case openVPNConfigHasInvalidEncoding
}

struct OpenVPNConfigImportHelper {

    // Read the OpenVPN config from the external file URL, make sure it parses
    // correctly, then copy it into the app's storage area.

    static func copyConfig(from url: URL) throws -> OpenVPNConfigInstance {
        guard let data = try? Data(contentsOf: url) else {
            throw OpenVPNConfigImportHelperError.openVPNConfigUnreadable
        }
        guard let configString = String(data: data, encoding: .utf8) else {
            throw OpenVPNConfigImportHelperError.openVPNConfigHasInvalidEncoding
        }

        let configLines = configString.components(separatedBy: .newlines)
        _ = try OpenVPN.ConfigurationParser.parsed(fromLines: configLines)

        let name = url.lastPathComponent
        let storagePath = UUID().uuidString
        let dataStore = PersistenceService.DataStore(path: storagePath)
        dataStore.vpnConfig = configString

        return OpenVPNConfigInstance(name: name, localStoragePath: storagePath)
    }
}
