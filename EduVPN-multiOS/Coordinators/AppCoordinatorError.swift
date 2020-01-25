//
//  AppCoordinatorError.swift
//  EduVPN
//
//  Created by Aleksandr Poddubny on 30/05/2019.
//  Copyright © 2019 SURFNet. All rights reserved.
//

import Foundation

enum AppCoordinatorError: LocalizedError {
    case certificateInvalid
    case certificateNil
    case certificateCommonNameNotFound
    case certificateStatusUnknown
    case apiMissing
    case profileIdMissing
    case apiProviderCreateFailed
    case sodiumSignatureFetchFailed
    case sodiumSignatureMissing
    case sodiumSignatureVerifyFailed
    case ovpnConfigTemplate
    case certificateModelMissing
    case ovpnConfigTemplateNoRemotes
    case missingStaticTargets
    case urlCreation
    case ovpnTemplate
    case discoverySeqNotIncremented
    
    var errorDescription: String {
        switch self {
        case .certificateInvalid:
            return NSLocalizedString("VPN certificate is invalid.", comment: "")
        case .certificateNil:
            return NSLocalizedString("VPN certificate should not be nil.", comment: "")
        case .certificateCommonNameNotFound:
            return NSLocalizedString("Unable to extract Common Name from VPN certificate.", comment: "")
        case .certificateStatusUnknown:
            return NSLocalizedString("VPN certificate status is unknown.", comment: "")
        case .apiMissing:
            return NSLocalizedString("No concrete API instance while expecting one.", comment: "")
        case .profileIdMissing:
            return NSLocalizedString("No concrete profileId while expecting one.", comment: "")
        case .apiProviderCreateFailed:
            return NSLocalizedString("Failed to create dynamic API provider.", comment: "")
        case .sodiumSignatureFetchFailed:
            return NSLocalizedString("Fetching signature failed.", comment: "")
        case .sodiumSignatureMissing:
            return NSLocalizedString("Verify signature missing.", comment: "")
        case .sodiumSignatureVerifyFailed:
            return NSLocalizedString("Signature verification of discovery file failed.", comment: "")
        case .ovpnConfigTemplate:
            return NSLocalizedString("Unable to materialize an OpenVPN config.", comment: "")
        case .certificateModelMissing:
            return NSLocalizedString("Missing certificate model.", comment: "")
        case .ovpnConfigTemplateNoRemotes:
            return NSLocalizedString("OpenVPN template has no remotes.", comment: "")
        case .missingStaticTargets:
            return NSLocalizedString("Static target configuration is incomplete.", comment: "")
        case .urlCreation:
            return NSLocalizedString("Failed to create URL.", comment: "")
        case .ovpnTemplate:
            return NSLocalizedString("OVPN template is not valid.", comment: "")
        case .discoverySeqNotIncremented:
            return NSLocalizedString("Discovery sequence number not incremented", comment: "")
        }
    }
}
