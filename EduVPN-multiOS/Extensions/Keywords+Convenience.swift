//
//  DisplayName+Convenience.swift
//  eduVPN
//

import Foundation

extension Set where Element == Keywords {
    
    var localizedValue: String? {
        var mapping = [String: String]()
        
        self.forEach {
            let locale = $0.locale ?? ""
            if let keywords = $0.keywords {
                mapping[locale] = keywords
            }
        }
        
        let preferedLocalization = Bundle.preferredLocalizations(from: Array(mapping.keys))
        for localeIdentifier in preferedLocalization {
            if let keywordsCandidate = mapping[localeIdentifier] {
                return keywordsCandidate
            }
        }
        
        return mapping[""]
    }
}
