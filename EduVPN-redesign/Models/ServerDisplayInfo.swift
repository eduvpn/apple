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
    func serverName(for locale: Locale, isTitle: Bool = false) -> String {
        switch self {
        case .instituteAccessServer(let server):
            return server.displayName.string(for: locale)
        case .secureInternetServer(let server):
            guard let server = server else { return NSLocalizedString("Unknown country", comment: "") }
            return Locale.current.localizedString(forRegionCode: server.countryCode) ??
                NSLocalizedString("Unknown country", comment: "")
        case .serverByURLServer(let server):
            if isTitle, let url = URL(string: server.baseURLString.urlString), let host = url.host, url.path == "/" {
                return host
            }
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
