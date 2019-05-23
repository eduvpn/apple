//
//  StaticService.swift
//  eduVPN
//
//  Created by Jeroen Leenarts on 01-08-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

import Foundation

import Moya

struct StaticService: TargetType, AcceptJson {
    
    enum StaticServiceType {
        case instituteAccess
        case instituteAccessSignature
        case secureInternet
        case secureInternetSignature
    }

    init?(type: StaticService.StaticServiceType) {
        guard let baseURL = Config.shared.discovery?.server else {
            return nil
        }

        self.baseURL = baseURL

        guard let path: String = Config.shared.discovery?.path(forServiceType: type) else {
            return nil
        }

        self.path = path
    }

    var method: Moya.Method { return .get }
    var task: Task { return .requestPlain }
    var sampleData: Data { return "".data(using: String.Encoding.utf8)! }

    var baseURL: URL
    var path: String

    static var publicKey: Data {
        return Config.shared.discovery!.signaturePublicKey!
    }
}
