//
//  ConnectionViewModel+Localization.swift
//  EduVPN
//

import Foundation

extension ConnectionViewModel.ConnectionFlowStatus {
    var localizedText: String {
        switch self {
        case .gettingProfiles: return NSLocalizedString("Getting profiles...", comment: "connection flow status")
        case .configuring: return NSLocalizedString("Configuring...", comment: "connection flow status")
        case .notConnected: return NSLocalizedString("Not connected", comment: "connection flow status")
        case .connecting: return NSLocalizedString("Connecting...", comment: "connection flow status")
        case .connected: return NSLocalizedString("Connected", comment: "connection flow status")
        case .reconnecting: return NSLocalizedString("Reconnecting...", comment: "connection flow status")
        case .disconnecting: return NSLocalizedString("Disconnecting...", comment: "connection flow status")
        }
    }
}

extension ConnectionViewModel.StatusDetail {
    var localizedText: String {
        switch self {
        case .none:
            return ""
        case .sessionStatus(let certificateStatus):
            return certificateStatus.localizedText
        case .noProfilesAvailable:
            return NSLocalizedString("No profiles available", comment: "connection status detail")
        }
    }
}
