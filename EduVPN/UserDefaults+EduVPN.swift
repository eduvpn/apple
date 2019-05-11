//
//  UserDefaults+EduVPN.swift
//  eduVPN
//
//  Created by Jeroen Leenarts on 21-08-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

import Foundation

private let onDemandDefaultsKey = "on_demand"
private let forceTcpDefaultsKey = "force_tcp"
private let configuredProfileUuidKey = "configured_profile_uuid"
private let tlsSecurityLevelKey = "tls_security_level"

/// For more details: https://www.openssl.org/docs/manmaster/man3/SSL_CTX_set_security_level.html
enum TlsSecurityLevel: Int {
    case bits128 = 3
    case bits192 = 4
    case bits256 = 5
}

extension UserDefaults {
    var onDemand: Bool {
        get {
            return bool(forKey: onDemandDefaultsKey)
        }
        set {
            set(newValue, forKey: onDemandDefaultsKey)
        }
    }

    var forceTcp: Bool {
        get {
            return bool(forKey: forceTcpDefaultsKey)
        }
        set {
            set(newValue, forKey: forceTcpDefaultsKey)
        }
    }

    var configuredProfileId: String? {
        get {
            return string(forKey: configuredProfileUuidKey)
        }
        set {
            set(newValue, forKey: configuredProfileUuidKey)
        }
    }

    var tlsSecurityLevel: TlsSecurityLevel {
        get {
            return TlsSecurityLevel(rawValue: integer(forKey: tlsSecurityLevelKey)) ?? TlsSecurityLevel.bits128
        }
        set {
            set(newValue.rawValue, forKey: tlsSecurityLevelKey)
        }
    }
}
