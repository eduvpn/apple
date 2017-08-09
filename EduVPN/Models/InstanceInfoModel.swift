//
//  InstanceInfoModel.swift
//  EduVPN
//
//  Created by Jeroen Leenarts on 08-08-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

import Foundation

struct InstanceInfoModel {

    var authorizationEndpoint: URL
    var tokenEndpoint: URL
    var apiBaseUrl: URL

    init?(json: [String: Any]?) {
        guard let api = json?["api"] as? [String: AnyObject] else {
            return nil
        }

        guard let apiInfo = api["http://eduvpn.org/api#2"] as? [String: AnyObject] else {
            return nil
        }

        guard let authorizationEndpointString = apiInfo["authorization_endpoint"] as? String, let authorizationEndpoint = URL(string: authorizationEndpointString) else {
            return nil
        }

        guard let tokenEndpointString = apiInfo["token_endpoint"] as? String, let tokenEndpoint = URL(string: tokenEndpointString) else {
            return nil
        }

        guard let apiBaseUrlString = apiInfo["api_base_uri"] as? String, let apiBaseUrl = URL(string: apiBaseUrlString) else {
            return nil
        }

        self.authorizationEndpoint = authorizationEndpoint
        self.tokenEndpoint = tokenEndpoint
        self.apiBaseUrl = apiBaseUrl
    }
}
