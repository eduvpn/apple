//
//  User.swift
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
