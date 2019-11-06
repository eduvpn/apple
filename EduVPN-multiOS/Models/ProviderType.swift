//
//  ProviderType.swift
//  eduVPN
//
//  Created by Jeroen Leenarts on 08-08-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

import Foundation

enum ProviderType: String, Codable {
    
    case unknown
    case secureInternet
    case instituteAccess
    case other
    case local
    
    var title: String {
        switch self {
            
        case .secureInternet:
            return NSLocalizedString("Secure Internet", comment: "")
            
        case .instituteAccess:
            return NSLocalizedString("Institute access", comment: "")
            
        case .other:
            #if os(iOS)
            return NSLocalizedString("Other", comment: "")
            #elseif os(macOS)
            return NSLocalizedString("Custom", comment: "")
            #endif
            
        case .local:
            return NSLocalizedString("Local", comment: "")
            
        case .unknown:
            #if os(iOS)
            return NSLocalizedString(".", comment: "")
            #elseif os(macOS)
            return NSLocalizedString("Unknown", comment: "")
            #endif
            
        }
    }
}
