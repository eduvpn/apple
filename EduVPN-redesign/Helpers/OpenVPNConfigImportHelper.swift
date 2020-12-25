//
//  OpenVPNConfigImportHelper.swift
//  EduVPN
//

import Foundation
import TunnelKit

enum OpenVPNConfigImportHelperError: Error {
    case openVPNConfigUnreadable
    case openVPNConfigHasInvalidEncoding
    case openVPNConfigHasNoRemotes
}

extension OpenVPNConfigImportHelperError: AppError {
    var summary: String {
        switch self {
        case .openVPNConfigUnreadable:
            return NSLocalizedString("OpenVPN config file is unreadable", comment: "")
        case .openVPNConfigHasInvalidEncoding:
            return NSLocalizedString("OpenVPN config file is not in UTF-8 encoding", comment: "")
        case .openVPNConfigHasNoRemotes:
            return NSLocalizedString("OpenVPN config file has no remotes", comment: "")
        }
    }
    var detail: String {
        NSLocalizedString("OpenVPN config was not imported", comment: "")
    }
}

extension TunnelKit.ConfigurationError: AppError {
    var summary: String {
        switch self {
        case .malformed(let option):
            return String(
                format: NSLocalizedString("OpenVPN config file is malformed: %@", comment: ""),
                option)
        case .missingConfiguration(let option):
            return String(
                format: NSLocalizedString("OpenVPN config file is missing configuration: %@", comment: ""),
                option)
        case .unsupportedConfiguration(let option):
            return String(
                format: NSLocalizedString("OpenVPN config file has unsupported configuration: %@", comment: ""),
                option)
        case .encryptionPassphrase:
            return NSLocalizedString("OpenVPN config file with encrypted client key is not supported", comment: "")
        case .unableToDecrypt(let error):
            return String(
                format: NSLocalizedString("OpenVPN config file cannot be decrypted: %@", comment: ""),
                error.localizedDescription)
        }
    }
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

        let hasRemote = configLines.contains(where: { $0.lowercased().hasPrefix("remote ") })
        guard hasRemote else {
            throw OpenVPNConfigImportHelperError.openVPNConfigHasNoRemotes
        }

        let name = url.lastPathComponent
        let storagePath = UUID().uuidString
        let dataStore = PersistenceService.DataStore(path: storagePath)
        dataStore.vpnConfig = configString

        return OpenVPNConfigInstance(name: name, localStoragePath: storagePath)
    }
}
