//
//  AuthState.swift
//  EduVPN
//

import AppAuth
import PromiseKit

// Simple wrapper around OIDAuthState

struct AuthState {
    let oidAuthState: OIDAuthState

    init(oidAuthState: OIDAuthState) {
        self.oidAuthState = oidAuthState
    }
}
