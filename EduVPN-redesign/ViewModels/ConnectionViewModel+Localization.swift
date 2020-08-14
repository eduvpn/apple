//
//  ConnectionViewModel+Localization.swift
//  EduVPN
//

import Foundation

extension ConnectionViewModel.SupportContact {
    var attributedStringValue: NSAttributedString {
        if supportContact.isEmpty {
            return NSAttributedString(string: "")
        }
        let contactStrings: [NSAttributedString] = supportContact.map { urlString in
            guard let url = URL(string: urlString) else {
                return NSAttributedString(string: urlString)
            }
            if urlString.hasPrefix("mailto:") {
                return NSAttributedString(
                    string: String(urlString.suffix(urlString.count - "mailto:".count)),
                    attributes: [.link: url])
            } else if urlString.hasPrefix("tel:") {
                return NSAttributedString(
                    string: String(urlString.suffix(urlString.count - "tel:".count)),
                    attributes: [.link: url])
            } else {
                return NSAttributedString(
                    string: urlString,
                    attributes: [.link: url])
            }
        }
        let resultString = NSMutableAttributedString(string: "")
        for (index, contactString) in contactStrings.enumerated() {
            if index > 0 {
                resultString.append(NSAttributedString(string: ", "))
            }
            resultString.append(contactString)
        }
        return resultString
    }
}

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
