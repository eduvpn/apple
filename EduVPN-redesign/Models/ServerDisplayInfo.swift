//
//  ServerDisplayInfo.swift
//  EduVPN-redesign-macOS
//

import Foundation

enum ServerDisplayInfo {
    case instituteAccessServer(DiscoveryData.InstituteAccessServer)
    case secureInternetServer(DiscoveryData.SecureInternetServer?)
    case serverByURLServer(SimpleServerInstance)
}

extension ServerDisplayInfo {
    func serverName(for locale: Locale) -> String {
        switch self {
        case .instituteAccessServer(let server):
            return server.displayName.string(for: locale)
        case .secureInternetServer(let server):
            guard let server = server else { return "Unknown country" }
            return Locale.current.localizedString(forRegionCode: server.countryCode) ?? "Unknown country"
        case .serverByURLServer(let server):
            return server.baseURLString.urlString
        }
    }

    var flagCountryCode: String {
        switch self {
        case .secureInternetServer(let server):
            return server?.countryCode ?? ""
        case .instituteAccessServer, .serverByURLServer:
            return ""
        }
    }

    var supportContact: [String] {
        switch self {
        case .instituteAccessServer(let server):
            return server.supportContact
        case .secureInternetServer(let server):
            return server?.supportContact ?? []
        case .serverByURLServer:
            return []
        }
    }
}
