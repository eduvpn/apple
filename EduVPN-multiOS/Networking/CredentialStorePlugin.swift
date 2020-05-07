//
//  CredentialStorePlugin.swift
//  eduVPN
//

import Foundation
import Moya

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
class CredentialStorePlugin: PluginType {

    /// The access token to be applied in the header.
    public var accessToken: String?

    /**
     Prepare a request by adding an authorization header if necessary.

     - parameters:
     - request: The request to modify.
     - target: The target of the request.
     - returns: The modified `URLRequest`.
     */
    public func prepare(_ request: URLRequest, target: TargetType) -> URLRequest {
        if let authorizable = target as? CredentialStoreAuthorizable, !authorizable.shouldAuthorize {
            return request
        }

        guard let token = accessToken else {
            return request
        }

        var request = request
        request.addValue("Bearer " + token, forHTTPHeaderField: "Authorization")

        return request
    }
}
