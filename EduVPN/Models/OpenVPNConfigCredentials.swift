//
//  OpenVPNConfigCredentials.swift
//  EduVPN
//

import Foundation

struct OpenVPNConfigCredentials {
    enum PasswordStrategy {
        // How should password be obtained when connecting

        case useSavedPassword(String)
        #if os(macOS)
        case askForPasswordWhenConnecting
        #endif
    }

    let userName: String
    let passwordStrategy: PasswordStrategy

    static let emptyCredentials: Self = Self(userName: "", passwordStrategy: .useSavedPassword(""))

    var isValid: Bool {
        if userName.isEmpty { return false }
        if case .useSavedPassword(let password) = passwordStrategy {
            if password.isEmpty { return false }
        }
        return true
    }
}

extension OpenVPNConfigCredentials: Codable {
    enum CodingKeys: String, CodingKey {
        case userName = "username"
        case password = "password"
        case askForPasswordWhenConnecting = "ask_password_when_connecting"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userName = try container.decode(String.self, forKey: .userName)

        #if os(macOS)
        if let shouldAskPasswordEveryTime = try container.decodeIfPresent(
               Bool.self, forKey: .askForPasswordWhenConnecting),
           shouldAskPasswordEveryTime {
            passwordStrategy = .askForPasswordWhenConnecting
        } else if let password = try container.decodeIfPresent(
                    String.self, forKey: .password) {
            passwordStrategy = .useSavedPassword(password)
        } else {
            passwordStrategy = .askForPasswordWhenConnecting
        }
        #endif

        #if os(iOS)
        let password = try container.decode(String.self, forKey: .password)
        passwordStrategy = .useSavedPassword(password)
        #endif
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userName, forKey: .userName)
        switch passwordStrategy {
        case .useSavedPassword(let password):
            try container.encode(password, forKey: .password)
        #if os(macOS)
        case .askForPasswordWhenConnecting:
            try container.encode(true, forKey: .askForPasswordWhenConnecting)
        #endif
        }
    }
}
