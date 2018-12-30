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

struct SystemMessages: Decodable {
    var systemMessages: [Message]
}

extension SystemMessages {
    enum SystemMessagesKeys: String, CodingKey {
        case systemMessages = "system_messages"
        case data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: SystemMessagesKeys.self)
        
        let messagesContainer = try container.nestedContainer(keyedBy: SystemMessagesKeys.self, forKey: .systemMessages)
        systemMessages = try messagesContainer.decode([Message].self, forKey: .data)
    }
    
    var displayString: String {
        return systemMessages.map(createString).joined(separator: "\n\n")
    }

}

struct Message: Decodable {
    var message: String
    var date_time: Date
    var type: NotificationType
}

private func createString(message: Message) -> String {
    return [displayDateFormatter.string(from: message.date_time), message.message].joined(separator: "\n")
}
