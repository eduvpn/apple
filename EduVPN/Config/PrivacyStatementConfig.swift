//
//  PrivacyStatementConfig.swift
//  EduVPN
//

import Foundation

struct PrivacyStatementConfig: Decodable {

    static var shared: PrivacyStatementConfig = {
        guard let url = Bundle.main.url(forResource: "privacy_statement", withExtension: "json") else {
            fatalError("This is very much hard coded. If this ever fails. It SHOULD crash.")
        }
        do {
            return try JSONDecoder().decode(PrivacyStatementConfig.self, from: Data(contentsOf: url))
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
