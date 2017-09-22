//
//  InstanceInfoModel.swift
//  EduVPN
//
//  Created by Jeroen Leenarts on 08-08-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

import Foundation
import AppAuth
import KeychainSwift

struct InstanceInfoModel: Codable {
    var authorizationEndpoint: URL
    var tokenEndpoint: URL
    var apiBaseUrl: URL
    var auth: OIDAuthState? {
        get {
            if let data = KeychainSwift().getData("instance-info-authState") {
                return NSKeyedUnarchiver.unarchiveObject(with: data) as? OIDAuthState
            } else {
                return nil
            }
        }
        set {
            if let newValue = newValue {
                let data = NSKeyedArchiver.archivedData(withRootObject: newValue)
                KeychainSwift().set(data, forKey: "instance-info-authState")
            } else {
                KeychainSwift().delete("instance-info-authState")
            }
        }
    }//TODO Store this to keychain in a instance-info specific way
}

extension InstanceInfoModel {
    enum InstanceInfoModelKeys: String, CodingKey {
        case api
        case apiInfo = "http://eduvpn.org/api#2"
        case authorizationEndpoint = "authorization_endpoint"
        case tokenEndpoint = "token_endpoint"
        case apiBaseUrl = "api_base_uri"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: InstanceInfoModelKeys.self)

        let apiContainer = try container.nestedContainer(keyedBy: InstanceInfoModelKeys.self, forKey: .api)
        let apiInfoContainer = try apiContainer.nestedContainer(keyedBy: InstanceInfoModelKeys.self, forKey: .apiInfo)

        let authorizationEndpoint = try apiInfoContainer.decode(URL.self, forKey: .authorizationEndpoint)
        let tokenEndpoint = try apiInfoContainer.decode(URL.self, forKey: .tokenEndpoint)
        let apiBaseUrl = try apiInfoContainer.decode(URL.self, forKey: .apiBaseUrl)

        self.init(authorizationEndpoint: authorizationEndpoint, tokenEndpoint: tokenEndpoint, apiBaseUrl: apiBaseUrl)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: InstanceInfoModelKeys.self)

        var apiContainer = container.nestedContainer(keyedBy: InstanceInfoModelKeys.self, forKey: .api)
        var apiInfoContainer = apiContainer.nestedContainer(keyedBy: InstanceInfoModelKeys.self, forKey: .apiInfo)

        try apiInfoContainer.encode(authorizationEndpoint, forKey: .authorizationEndpoint)
        try apiInfoContainer.encode(tokenEndpoint, forKey: .tokenEndpoint)
        try apiInfoContainer.encode(apiBaseUrl, forKey: .apiBaseUrl)
    }
}

extension InstanceInfoModel: Hashable {
    var hashValue: Int {
        return apiBaseUrl.hashValue
    }

    static func == (lhs: InstanceInfoModel, rhs: InstanceInfoModel) -> Bool {
        return lhs.apiBaseUrl == rhs.apiBaseUrl
    }
}
