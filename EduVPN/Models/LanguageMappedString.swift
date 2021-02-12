//
//  LanguageMappedString.swift
//  EduVPN
//

// Represents a string that can differ based on the language.

// Some fields in the responses from the server might be either a simple
// string, or a dictionary mapping language tags to strings.
//
// For example, a display name field could be either:
//     "display_name": "SURFnet bv"
// or:
//     "display_name": { "en": "SURFnet", "nl": "SURFnet bv" }
//
// The actual string to display should be derived based on the current locale.
// The LanguageMappedString type represents a string like this.

import Foundation

enum LanguageMappedString {
    case stringForAnyLanguage(String)
    case stringByLanguageTag([String: String])
}

extension LanguageMappedString: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let dictionary = try? container.decode([String: String].self) {
            self = .stringByLanguageTag(dictionary)
        } else {
            let string = try container.decode(String.self)
            self = .stringForAnyLanguage(string)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .stringForAnyLanguage(let string):
            try container.encode(string)
        case .stringByLanguageTag(let dictionary):
            try container.encode(dictionary)
        }
    }
}

extension LanguageMappedString {

    // Implements the language matching rules described at:
    // https://github.com/eduvpn/documentation/blob/v2/SERVER_DISCOVERY.md#language-matching

    func string(for locale: Locale) -> String {
        let languageTag: String = {
            // Find out the BCP47 tag of the current system language
            if let preferredLanguage = Locale.preferredLanguages.first {
                return preferredLanguage
            }
            var tag = locale.languageCode ?? "en"
            if !tag.contains("-") {
                // Append the region / script / variant designator, so
                // "de" can become "de-DE", "zh" can become "zh-Hant", etc.
                if let scriptCode = locale.scriptCode {
                    tag.append("-\(scriptCode)")
                }
                if let regionCode = locale.regionCode {
                    tag.append("-\(regionCode)")
                }
                if let variantCode = locale.variantCode {
                    tag.append("-\(variantCode)")
                }
            }
            return tag
        }()
        switch self {
        case .stringForAnyLanguage(let string):
            return string
        case .stringByLanguageTag(let map):
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
            let dashIndex = languageTag.firstIndex(of: "-") ?? languageTag.endIndex
            let languageCode = languageTag[languageTag.startIndex ..< dashIndex]
            if !languageCode.isEmpty,
               let prefixMatch = map.keys.first(where: { $0.hasPrefix("\(languageCode)-") }) {
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
