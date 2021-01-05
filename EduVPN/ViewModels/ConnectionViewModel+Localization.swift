//
//  ConnectionViewModel+Localization.swift
//  EduVPN
//

import Foundation

extension ConnectionViewModel.Status {
    var localizedText: String {
        switch self {
        case .gettingProfiles: return NSLocalizedString("Getting profiles...", comment: "")
        case .configuring: return NSLocalizedString("Configuring...", comment: "")
        case .notConnected: return NSLocalizedString("Not connected", comment: "")
        case .connecting: return NSLocalizedString("Connecting...", comment: "")
        case .connected: return NSLocalizedString("Connected", comment: "")
        case .reconnecting: return NSLocalizedString("Reconnecting...", comment: "")
        case .disconnecting: return NSLocalizedString("Disconnecting...", comment: "")
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
            return NSLocalizedString("No profiles available", comment: "")
        }
    }
}
