//
//  AuthState.swift
//  EduVPN
//

import AppAuth
import PromiseKit

// Simple wrapper around OIDAuthState

enum AuthStateError: Error {
    case authStateUnauthorized(authorizationError: Error)
}

struct AuthState {
    let oidAuthState: OIDAuthState

    init(oidAuthState: OIDAuthState) {
        self.oidAuthState = oidAuthState
    }

    func getFreshAccessToken(storingChangesTo dataStore: PersistenceService.DataStore)
        -> Promise<String> {
        return Promise { seal in
            self.oidAuthState.stateChangeDelegate = dataStore
            self.oidAuthState.performAction { (accessToken, _, error) in
                self.oidAuthState.stateChangeDelegate = nil
                if let authorizationError = self.oidAuthState.authorizationError {
                    let error = AuthStateError.authStateUnauthorized(
                        authorizationError: authorizationError)
                    seal.reject(error)
                } else {
                    seal.resolve(accessToken, error)
                }
            }
        }
    }
}
