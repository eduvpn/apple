//
//  Logo+Convenience.swift
//  eduVPN
//

import Foundation

extension Set where Element == Logo {
    
    var localizedValue: String? {
        var mapping = [String: String]()
        
        self.forEach {
            let locale = $0.locale ?? ""
            if let logo = $0.logo {
                mapping[locale] = logo
            }
        }
        
        let preferedLocalization = Bundle.preferredLocalizations(from: Array(mapping.keys))
        for localeIdentifier in preferedLocalization {
            if let displayNameCandidate = mapping[localeIdentifier] {
                return displayNameCandidate
            }
        }
        
        return mapping[""]
    }
}
