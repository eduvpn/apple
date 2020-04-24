//
//  ProviderType.swift
//  eduVPN
//

import Foundation

enum ProviderType: String, Codable {
    
    case unknown
    case organization
    case secureInternet
    case instituteAccess
    case other
    case local
    
    var title: String {
        switch self {
          
        case .organization:
            return "TODO"
            
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
//
//extension Provider {
//
//    var providerType: ProviderType {
//        switch cas
//    }
//
//}
