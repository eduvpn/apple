//
//  StaticService.swift
//  EduVPN
//
//  Created by Jeroen Leenarts on 01-08-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

import Foundation

import Moya

private let publicKey = Data(base64Encoded: "E5On0JTtyUVZmcWd+I/FXRm32nSq8R2ioyW7dcu/U88=")

enum StaticService {
    case instances
    case instancesSignature
    case federation
    case federationSignature
}

extension StaticService: TargetType {
    var baseURL: URL { return URL(string: "https://static.eduvpn.nl")! }

    var path: String {
        switch self {
        case .instances:
            return "/instances-dev.json"
        case .instancesSignature:
            return "/instances.json.sig"
        case .federation:
            return "/federation.json"
        case .federationSignature:
            return "/federation.json.sig"
        }
    }

    var method: Moya.Method {
        switch self {
        case .instances, .instancesSignature, .federation, .federationSignature:
            return .get
        }
    }

    var parameters: [String: Any]? {
        switch self {
        case .instances, .instancesSignature, .federation, .federationSignature:
            return nil
        }
    }

    var parameterEncoding: ParameterEncoding {
        switch self {
        case .instances, .instancesSignature, .federation, .federationSignature:
            return JSONEncoding.default
        }
    }

    var task: Task {
        switch self {
        case .instances, .instancesSignature, .federation, .federationSignature:
            return .request
        }
    }

    var sampleData: Data {
        return "".data(using: String.Encoding.utf8)!
    }
}
