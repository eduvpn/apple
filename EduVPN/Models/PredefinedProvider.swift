//
//  PredefinedProvider.swift
//  EduVPN
//

import Foundation

struct PredefinedProvider {
    let baseURLString: DiscoveryData.BaseURLString
    let displayName: LanguageMappedString
}

extension PredefinedProvider: Decodable {
    enum CodingKeys: String, CodingKey {
        case baseURLString = "base_url"
        case displayName = "display_name"
    }
}
