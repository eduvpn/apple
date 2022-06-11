//
//  PrivacyDisclaimerConfig.swift
//  EduVPN
//

import Foundation

struct PrivacyDisclaimerConfig: Decodable {

    static var shared: PrivacyDisclaimerConfig = {
        guard let url = Bundle.main.url(forResource: "privacy_disclaimer_config", withExtension: "json") else {
            fatalError("This is very much hard coded. If this ever fails. It SHOULD crash.")
        }
        do {
            return try JSONDecoder().decode(PrivacyDisclaimerConfig.self, from: Data(contentsOf: url))
        } catch {
            fatalError("Failed to load config \(url) due to error: \(error)")
        }
    }()

    enum ConfigKeys: String, CodingKey {
        case title
        case lines
    }

    var title: String
    var text: String

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: ConfigKeys.self)
        title = try container.decode(String.self, forKey: .title)
        let lines = try container.decode([String].self, forKey: .lines)
        text = lines.joined(separator: "\n")
    }
}
