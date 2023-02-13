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

    func hasSameEndpoints(as serverInfo: ServerInfo) -> Bool {
        let oidServiceConfig = oidAuthState.lastAuthorizationResponse.request.configuration
        return ((oidServiceConfig.authorizationEndpoint == serverInfo.authorizationEndpoint) &&
                (oidServiceConfig.tokenEndpoint == serverInfo.tokenEndpoint))
    }
}
