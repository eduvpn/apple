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
        case baseURLString = "url"
        case displayName = "display_name"
    }
}
