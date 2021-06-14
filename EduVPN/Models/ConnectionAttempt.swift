//
//  ConnectionAttempt.swift
//  EduVPN
//

// On app launch, if VPN is enabled, we want to be able to restore the
// app to a state where the corresponding connection UI screen is showing.
// The ConnectionAttempt struct contains the information required for
// performing this restoration.

import Foundation
import os.log

enum ConnectionAttemptDecodingError: Error {
    case unknownConnectableInstance
}

struct ConnectionAttempt {
    struct ServerPreConnectionState {
        // The state before connection was attempted to a ServerInstance
        let profiles: [Profile]
        let selectedProfileId: String
        let certificateValidFrom: Date
        let certificateExpiresAt: Date
    }

    struct VPNConfigPreConnectionState {
        let shouldAskForPasswordOnReconnect: Bool
    }

    enum PreConnectionState {
        case serverState(ServerPreConnectionState)
        case vpnConfigState(VPNConfigPreConnectionState)

        var serverState: ServerPreConnectionState? {
            switch self {
            case .serverState(let serverState): return serverState
            case .vpnConfigState: return nil
            }
        }

        var vpnConfigState: VPNConfigPreConnectionState? {
            switch self {
            case .serverState: return nil
            case .vpnConfigState(let vpnConfigState): return vpnConfigState
            }
        }
    }

    let connectableInstance: ConnectableInstance
    let preConnectionState: PreConnectionState
    let attemptId: UUID

    init(server: ServerInstance, profiles: [Profile],
         selectedProfileId: String,
         certificateValidityRange: ServerAPIService.CertificateValidityRange,
         attemptId: UUID) {
        self.connectableInstance = server
        self.preConnectionState = .serverState(
            ServerPreConnectionState(
                profiles: profiles, selectedProfileId: selectedProfileId,
                certificateValidFrom: certificateValidityRange.validFrom,
                certificateExpiresAt: certificateValidityRange.expiresAt))
        self.attemptId = attemptId
    }

    init(vpnConfigInstance: VPNConfigInstance, shouldAskForPasswordOnReconnect: Bool, attemptId: UUID) {
        self.connectableInstance = vpnConfigInstance
        self.preConnectionState = .vpnConfigState(
            VPNConfigPreConnectionState(
                shouldAskForPasswordOnReconnect: shouldAskForPasswordOnReconnect))
        self.attemptId = attemptId
    }
}

extension ConnectionAttempt.ServerPreConnectionState: Codable {
    enum CodingKeys: String, CodingKey {
        case profiles
        case selectedProfileId = "selected_profile_id"
        case certificateValidFrom = "certificate_valid_from"
        case certificateExpiresAt = "certificate_expires_at"
    }
}

extension ConnectionAttempt.VPNConfigPreConnectionState: Codable {
    enum CodingKeys: String, CodingKey {
        case shouldAskForPasswordOnReconnect = "should_ask_for_password_on_reconnect"
    }
}

extension ConnectionAttempt: Codable {
    enum CodingKeys: String, CodingKey {
        case simpleServer = "simple_server"
        case secureInternetServer = "secure_internet_server"
        case openVPNConfig = "ovpn_config"
        case preConnectionState = "pre_connection_state"
        case attemptId = "attempt_id"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let simpleServer = try container.decodeIfPresent(
            SimpleServerInstance.self, forKey: .simpleServer) {
            connectableInstance = simpleServer
        } else if let secureInternetServer = try container.decodeIfPresent(
            SecureInternetServerInstance.self, forKey: .secureInternetServer) {
            connectableInstance = secureInternetServer
        } else if let openVPNConfigInstance = try container.decodeIfPresent(
            OpenVPNConfigInstance.self, forKey: .openVPNConfig) {
            connectableInstance = openVPNConfigInstance
        } else {
            throw ConnectionAttemptDecodingError.unknownConnectableInstance
        }
        if connectableInstance is OpenVPNConfigInstance {
            let vpnConfigState = try container.decodeIfPresent(
                VPNConfigPreConnectionState.self, forKey: .preConnectionState) ??
                VPNConfigPreConnectionState(shouldAskForPasswordOnReconnect: false)
            preConnectionState = .vpnConfigState(vpnConfigState)
        } else if connectableInstance is ServerInstance {
            let serverState = try container.decode(
                ServerPreConnectionState.self, forKey: .preConnectionState)
            preConnectionState = .serverState(serverState)
        } else {
            throw ConnectionAttemptDecodingError.unknownConnectableInstance
        }
        attemptId = try container.decode(UUID.self, forKey: .attemptId)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let simpleServer = connectableInstance as? SimpleServerInstance {
            try container.encode(simpleServer, forKey: .simpleServer)
        } else if let secureInternetServer = connectableInstance as? SecureInternetServerInstance {
            try container.encode(secureInternetServer, forKey: .secureInternetServer)
        } else if let openVPNConfigInstance = connectableInstance as? OpenVPNConfigInstance {
            try container.encode(openVPNConfigInstance, forKey: .openVPNConfig)
        }
        switch preConnectionState {
        case .serverState(let serverState):
            try container.encode(serverState, forKey: .preConnectionState)
        case .vpnConfigState(let vpnConfigState):
            try container.encode(vpnConfigState, forKey: .preConnectionState)
        }
        try container.encode(attemptId, forKey: .attemptId)
    }
}
