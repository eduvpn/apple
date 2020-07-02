//
//  AuthState.swift
//  EduVPN
//

import AppAuth

// Simple wrapper around OIDAuthState

struct AuthState {
    let oidAuthState: OIDAuthState

    init(oidAuthState: OIDAuthState) {
        self.oidAuthState = oidAuthState
    }
}
