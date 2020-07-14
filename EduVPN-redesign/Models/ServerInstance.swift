//
//  ServerInstance.swift
//  EduVPN
//

import Foundation

protocol ServerInstance {
    var apiBaseURLString: DiscoveryData.BaseURLString { get }
    var authBaseURLString: DiscoveryData.BaseURLString { get }
    var localStoragePath: String { get }
}

struct SimpleServerInstance: ServerInstance {
    let baseURLString: DiscoveryData.BaseURLString
    let localStoragePath: String

    var apiBaseURLString: DiscoveryData.BaseURLString { baseURLString }
    var authBaseURLString: DiscoveryData.BaseURLString { baseURLString }
}

struct SecureInternetServerInstance: ServerInstance {
    let apiBaseURLString: DiscoveryData.BaseURLString
    let authBaseURLString: DiscoveryData.BaseURLString
    let orgId: String
    let localStoragePath: String
}

extension SimpleServerInstance: Codable {
    enum CodingKeys: String, CodingKey {
        case baseURLString = "base_url"
        case localStoragePath = "local_storage_path"
    }
}

extension SecureInternetServerInstance: Codable {
    enum CodingKeys: String, CodingKey {
        case apiBaseURLString = "api_base_url"
        case authBaseURLString = "auth_base_url"
        case orgId = "org_id"
        case localStoragePath = "local_storage_path"
    }
}
