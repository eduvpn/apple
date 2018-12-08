//
//  Message.swift
//  EduVPN
//
//  Created by Jeroen Leenarts on 03/12/2018.
//  Copyright © 2018 SURFNet. All rights reserved.
//

import Foundation

// swiftlint:disable identifier_name

let displayDateFormatter: DateFormatter = {
    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .medium
    dateFormatter.timeStyle = .medium
    return dateFormatter
}()

enum NotificationType: String, Decodable {
    case notification
    case motd
    case maintenance
}

struct Messages: Decodable {
    var system_messages: DataMessage?
    var user_messages: DataMessage?
}

struct DataMessage: Decodable {
    var data: [Message]
    var ok: Bool
}

struct Message: Decodable {
    var message: String
    var date_time: Date
    var type: NotificationType
}

extension Messages {
    var displayString: String? {
        if let systemMessageStrings = system_messages?.data.map(createString) {
            return joinMessageStrings(systemMessageStrings)
        }
        if let userMessageStrings = user_messages?.data.map(createString) {
            return joinMessageStrings(userMessageStrings)
        }

        return nil
    }
}

private func createString(message: Message) -> String {
    return [displayDateFormatter.string(from: message.date_time), message.message].joined(separator: "\n\n")
}

private func joinMessageStrings(_ messageStrings: [String]) -> String? {
    if messageStrings.isEmpty {
        return nil
    }

    return messageStrings.joined(separator: "\n\n\n")
}
