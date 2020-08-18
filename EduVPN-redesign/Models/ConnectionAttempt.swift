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
    case unknownServerInstance
}

struct ConnectionAttempt {
    struct PreConnectionState {
        // The state before connection was attempted
        let profiles: [ProfileListResponse.Profile]
        let selectedProfileId: String
        let certificateValidFrom: Date
        let certificateExpiresAt: Date
    }

    let server: ServerInstance
    let preConnectionState: PreConnectionState
    let attemptId: UUID

    init?(server: ServerInstance, profiles: [ProfileListResponse.Profile],
          selectedProfileId: String,
          certificateValidityRange: ServerAPIService.CertificateValidityRange,
          attemptId: UUID) {
        self.server = server
        self.preConnectionState = PreConnectionState(
            profiles: profiles, selectedProfileId: selectedProfileId,
            certificateValidFrom: certificateValidityRange.validFrom,
            certificateExpiresAt: certificateValidityRange.expiresAt)
        self.attemptId = attemptId
        if !profiles.contains(where: { $0.profileId == selectedProfileId }) {
            return nil
        }
    }
}

extension ConnectionAttempt.PreConnectionState: Codable {
    enum CodingKeys: String, CodingKey {
        case profiles
        case selectedProfileId = "selected_profile_id"
        case certificateValidFrom = "certificate_valid_from"
        case certificateExpiresAt = "certificate_expires_at"
    }
}

extension ConnectionAttempt: Codable {
    enum CodingKeys: String, CodingKey {
        case simpleServer = "simple_server"
        case secureInternetServer = "secure_internet_server"
        case preConnectionState = "pre_connection_state"
        case attemptId = "attempt_id"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let simpleServer = try container.decodeIfPresent(
            SimpleServerInstance.self, forKey: .simpleServer) {
            server = simpleServer
        } else if let secureInternetServer = try container.decodeIfPresent(
            SecureInternetServerInstance.self, forKey: .secureInternetServer) {
            server = secureInternetServer
        } else {
            throw ConnectionAttemptDecodingError.unknownServerInstance
        }
        preConnectionState = try container.decode(
            PreConnectionState.self, forKey: .preConnectionState)
        attemptId = try container.decode(UUID.self, forKey: .attemptId)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let simpleServer = server as? SimpleServerInstance {
            try container.encode(simpleServer, forKey: .simpleServer)
        } else if let secureInternetServer = server as? SecureInternetServerInstance {
            try container.encode(secureInternetServer, forKey: .secureInternetServer)
        }
        try container.encode(preConnectionState, forKey: .preConnectionState)
        try container.encode(attemptId, forKey: .attemptId)
    }
}
