//
//  ProviderType.swift
//  eduVPN
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
            return NSLocalizedString("Other", comment: "")
            
        case .local:
            return NSLocalizedString("Local", comment: "")
            
        case .unknown:
            return NSLocalizedString("Unknown", comment: "")

        }
    }
}
