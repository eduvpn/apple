//
//  UserInfo.swift
//  eduVPN
//
//  Created by Johan Kool on 16/04/2018.
//  Copyright © 2017-2019 Commons Conservancy.
//

import Foundation

struct UserInfo {
    
    let twoFactorEnrolled: Bool
    let twoFactorEnrolledWith: [TwoFactorType]
    let isDisabled: Bool
}

enum TwoFactorType: String {
    case totp
    case yubico
}

enum TwoFactor {
    case totp(String)
    case yubico(String)
    
    var twoFactorType: TwoFactorType {
        switch self {
        case .totp:
            return .totp
        case .yubico:
            return .yubico
        }
    }
}

//struct ProviderInfo: Codable {
//    
//    let apiBaseURL: URL
//    let authorizationURL: URL
//    let tokenURL: URL
//    let provider: InstancesModel
//}
