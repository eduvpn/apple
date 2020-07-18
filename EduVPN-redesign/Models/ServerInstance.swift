//
//  ServerInstance.swift
//  EduVPN
//

import Foundation

protocol ServerInstance {
    var apiBaseURL: URL { get }
    var authBaseURL: URL { get }
    var localStoragePath: String { get }
}

struct SimpleServerInstance: ServerInstance {
    let baseURL: URL
    let localStoragePath: String

    var apiBaseURL: URL { baseURL }
    var authBaseURL: URL { baseURL }
}

struct SecureInternetServerInstance: ServerInstance {
    let apiBaseURL: URL
    let authBaseURL: URL
    let orgId: String
    let localStoragePath: String
}

extension SimpleServerInstance: Codable {
    enum CodingKeys: String, CodingKey {
        case baseURL = "base_url"
        case localStoragePath = "local_storage_path"
    }
}

extension SecureInternetServerInstance: Codable {
    enum CodingKeys: String, CodingKey {
        case apiBaseURL = "api_base_url"
        case authBaseURL = "auth_base_url"
        case orgId = "org_id"
        case localStoragePath = "local_storage_path"
    }
}
