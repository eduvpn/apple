//
//  DisplayName+Convenience.swift
//  eduVPN
//
//  Created by Jeroen Leenarts on 04-02-18.
//  Copyright © 2018 SURFNet. All rights reserved.
//

import Foundation

extension Set where Element  == DisplayName {
    var localizedValue: String? {
        var mapping = [String: String]()

        self.forEach {
            let locale = $0.locale ?? ""
            if let displayName = $0.displayName {
                mapping[locale] = displayName
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
