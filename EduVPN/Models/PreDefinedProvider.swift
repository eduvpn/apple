//
//  PreDefinedProvider.swift
//  EduVPN
//

import Foundation

struct PreDefinedProvider {
    let baseURLString: DiscoveryData.BaseURLString
    let displayName: LanguageMappedString
}

extension PreDefinedProvider: Decodable {
    enum CodingKeys: String, CodingKey {
        case baseURLString = "base_url"
        case displayName = "display_name"
    }
}
