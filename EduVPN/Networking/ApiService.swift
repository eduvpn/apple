//
//  ApiService.swift
//  EduVPN
//
//  Created by Jeroen Leenarts on 02-08-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

import Foundation

import Moya

enum ApiService {
    case profileList
    case userInfo
    case createConfig(displayName: String, profileId: String)
    case createKeypair(displayName: String)
    case profileConfig(profileId: String)
    case systemMessages
    case userMessages
}

extension ApiService {
    var path: String {
        switch self {
        case .profileList:
            return "/profile_list"
        case .userInfo:
            return "/user_info"
        case .createConfig:
            return "/create_config"
        case .createKeypair:
            return "/create_keypair"
        case .profileConfig:
            return "/profile_config"
        case .systemMessages:
            return "/system_messages"
        case .userMessages:
            return "/user_messages"
        }
    }

    var method: Moya.Method {
        switch self {
        case .profileList, .userInfo, .profileConfig, .systemMessages, .userMessages:
            return .get
        case .createConfig, .createKeypair:
            return .post
        }
    }

    var parameters: [String: Any]? {
        switch self {
        case .profileList, .userInfo, .systemMessages, .userMessages:
            return nil
        case .createConfig(let displayName, let profileId):
            return ["display_name": displayName, "profile_id": profileId]
        case .createKeypair(let displayName):
            return ["display_name": displayName]
        case .profileConfig(let profileId):
            return ["profile_id": profileId]
        }
    }

    var parameterEncoding: ParameterEncoding {
        return URLEncoding.default // Send parameters in URL for GET, DELETE and HEAD. For other HTTP methods, parameters will be sent in request body
    }

    var task: Task {
        return .request
    }

    var sampleData: Data {
        return "".data(using: String.Encoding.utf8)!
    }
}

struct DynamicApiService: TargetType {
    let baseURL: URL
    let apiService: ApiService

    var path: String { return apiService.path }
    var method: Moya.Method { return apiService.method }
    var parameters: [String: Any]? { return apiService.parameters }
    var parameterEncoding: ParameterEncoding { return apiService.parameterEncoding }
    var task: Task { return apiService.task }
    var sampleData: Data { return apiService.sampleData }
}
