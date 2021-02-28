//
//  ServerInstance.swift
//  EduVPN
//

import Foundation

// A connectable instance is something that we use to make a VPN connection
// to a server.

protocol ConnectableInstance {
    var localStoragePath: String { get }
}

extension ConnectableInstance {
    func isEqual(to other: ConnectableInstance) -> Bool {
        return localStoragePath == other.localStoragePath
    }
}

// A ServerInstance represents an EduVPN / Let's Connect server

protocol ServerInstance: ConnectableInstance {
    var apiBaseURLString: DiscoveryData.BaseURLString { get }
    var authBaseURLString: DiscoveryData.BaseURLString { get }
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

// A VPNConfigInstance represents a VPN-config-based server

enum VPNConfigType {
    case openVPNConfiguration
}

protocol VPNConfigInstance: ConnectableInstance {
    var configType: VPNConfigType { get }
    var name: String { get }
}

struct OpenVPNConfigInstance: VPNConfigInstance {
    var configType: VPNConfigType { .openVPNConfiguration }
    let name: String
    let localStoragePath: String
}

extension OpenVPNConfigInstance: Codable {
    enum CodingKeys: String, CodingKey {
        case name
        case localStoragePath = "local_storage_path"
    }
}
