//
//  CredentialStorePlugin.swift
//  EduVPN
//
//  Created by Jeroen Leenarts on 04-08-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

import Foundation
import Moya
import Result

// MARK: - CredentialStoreAuthorizable

/// A protocol for controlling the behavior of `CredentialStorePlugin`.
protocol CredentialStoreAuthorizable {

    /// Declares whether or not `CredentialStorePlugin` should add an authorization header
    /// to requests.
    var shouldAuthorize: Bool { get }
}

// MARK: - CredentialStorePlugin

/**
 A plugin for adding bearer-type authorization headers to requests. Example:

 ```
 Authorization: Bearer <token>
 ```

 - Note: By default, requests to all `TargetType`s will receive this header. You can control this
 behvaior by conforming to `CredentialStoreAuthorizable`.
 */
struct CredentialStorePlugin: PluginType {

    /// The access token to be applied in the header.
    static public var accessToken: String? = "fetch-me"

    /**
     Prepare a request by adding an authorization header if necessary.

     - parameters:
     - request: The request to modify.
     - target: The target of the request.
     - returns: The modified `URLRequest`.
     */
    public func prepare(_ request: URLRequest, target: TargetType) -> URLRequest {

        if let authorizable = target as? CredentialStoreAuthorizable, authorizable.shouldAuthorize == false {
            return request
        }

        guard let token = CredentialStorePlugin.accessToken else {
            return request
        }

        var request = request

        request.addValue("Bearer " + token, forHTTPHeaderField: "Authorization")

        return request
    }
}
