//
//  DiscoveryData+Locale.swift
//  EduVPN
//

import Foundation

// Locale-related helpers for the DiscoveryData model

extension DiscoveryData.LanguageMappedString {

    // Implements the language matching rules described at:
    // https://github.com/eduvpn/documentation/blob/v2/SERVER_DISCOVERY.md#language-matching

    func string(for locale: Locale) -> String {
        switch self {
        case .stringForAnyLanguage(let string):
            return string
        case .stringByLanguageTag(let map):
            // We're only looking for the language part of the locale
            let localeLanguageCode = locale.languageCode ?? "en"
            let languageTag: String = {
                if !localeLanguageCode.contains("-") {
                    // Append the region or script designator, so
                    // "de" can become "de-DE", and "zh" can become "zh-Hant".
                    if let designator = locale.regionCode ?? locale.scriptCode {
                        return "\(localeLanguageCode)-\(designator)"
                    }
                }
                return localeLanguageCode
            }()

            // Let's say the locale's language code is "de-DE".
            // First, look for a key equal to "de-DE"
            if let value = map[languageTag] {
                return value
            }

            // Then, look for a key that starts with "de-DE"
            if let prefixMatch = map.keys.first(where: { $0.hasPrefix(languageTag) }) {
                return map[prefixMatch]! // swiftlint:disable:this force_unwrapping
            }

            // Then, look for a key that starts with "de-"
            if let prefixMatch = map.keys.first(where: { $0.hasPrefix("\(localeLanguageCode)-") }) {
                return map[prefixMatch]! // swiftlint:disable:this force_unwrapping
            }

            // Then, look for a key equal to "en-US"
            if let value = map["en-US"] {
                return value
            }

            // Then, look for a key that starts with "en"
            if let prefixMatch = map.keys.first(where: { $0.hasPrefix("en") }) {
                return map[prefixMatch]! // swiftlint:disable:this force_unwrapping
            }

            // If all that fails, return an arbitrary (but predictable) value from the map
            if let lexicallyFirstKey = map.keys.sorted().first {
                return map[lexicallyFirstKey]! // swiftlint:disable:this force_unwrapping
            }

            // If the map is empty, return a constant string
            return "Unknown"
        }
    }
}
