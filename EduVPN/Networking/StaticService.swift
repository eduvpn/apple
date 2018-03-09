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
    case instituteAccess
    case instituteAccessSignature
    case secureInternet
    case secureInternetSignature
}

extension StaticService: TargetType, AcceptJson {
    var baseURL: URL { return URL(string: "https://static.eduvpn.nl/disco")! }

    var path: String {
        if let bundleID = Bundle.main.bundleIdentifier, bundleID.contains("appforce1") {
            switch self {
            case .instituteAccess:
                return "/institute_access_dev.json"
            case .instituteAccessSignature:
                return "/institute_access_dev.json.sig"
            case .secureInternet:
                return "/secure_internet_dev.json"
            case .secureInternetSignature:
                return "/secure_internet_dev.json.sig"
            }
        } else {
            switch self {
            case .instituteAccess:
                return "/institute_access.json"
            case .instituteAccessSignature:
                return "/institute_access.json.sig"
            case .secureInternet:
                return "/secure_internet.json"
            case .secureInternetSignature:
                return "/secure_internet.json.sig"
            }
        }
    }

    var method: Moya.Method {
        switch self {
        case .instituteAccess, .instituteAccessSignature, .secureInternet, .secureInternetSignature:
            return .get
        }
    }

    var task: Task {
        switch self {
        case .instituteAccess, .instituteAccessSignature, .secureInternet, .secureInternetSignature:
            return .requestPlain
        }
    }

    var sampleData: Data {
        return "".data(using: String.Encoding.utf8)!
    }
}
