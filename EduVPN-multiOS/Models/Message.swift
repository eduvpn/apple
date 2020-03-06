//
//  Message.swift
//  eduVPN
//

import Foundation

private let displayDateFormatter: DateFormatter = {
    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .medium
    dateFormatter.timeStyle = .medium
    return dateFormatter
}()

enum MessageAudience {
    case system
    case user
}

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
        let systemMessages = try messagesContainer.decode([Message].self, forKey: .data)
        
        // Temporarily apply field value here to support macOS cross-platform compability
        self.systemMessages = systemMessages.map {
            var message = $0
            message.audience = .system
            return message
        }
    }
    
    var displayString: String {
        return systemMessages.compactMap { $0.displayString }.joined(separator: "\n\n")
    }
}

struct Message: Decodable {
    
    var message: String?
    var messages: [String: String]?
    var date: Date
    var beginDate: Date?
    var endDate: Date?
    var type: NotificationType
    var audience: MessageAudience = .user
    
    // Backward-compability constructor to support macOS interface
    init(type: NotificationType,
         audience: MessageAudience,
         message: String,
         date: Date,
         beginDate: Date?,
         endDate: Date?) {
        
        self.type = type
        self.audience = audience
        self.message = message
        self.date = date
        self.beginDate = beginDate
        self.endDate = endDate
    }
}

extension Message {
    
    enum MessageKeys: String, CodingKey {
        case message
        case date = "date_time"
        case beginDate = "begin"
        case endDate = "end"
        case type
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: MessageKeys.self)
        
        type = try container.decode(NotificationType.self, forKey: .type)
        
        date = try container.decode(Date.self, forKey: .date)
        beginDate = try? container.decode(Date.self, forKey: .beginDate)
        endDate = try? container.decode(Date.self, forKey: .endDate)
        
        // Here we try to deocde the `message` key into both a String and a [String: String]. The localizedMessage implementatation tries to obtain the "locale correct" value.
        message = try? container.decode(String.self, forKey: .message)
        messages = try? container.decode([String: String].self, forKey: .message)
    }
}

extension Message {
    
    var localizedMessage: String? {
        if let messages = messages {
            let preferedLocalization = Bundle.preferredLocalizations(from: Array(messages.keys))
            for localeIdentifier in preferedLocalization {
                if let localizedCandidate = messages[localeIdentifier] {
                    return localizedCandidate
                }
            }
        } else if let message = message {
            return message
        }
        
        return ""
    }
    
    var displayString: String? {
        guard let message = localizedMessage else {
            return nil
        }
        
        return [displayDateFormatter.string(from: date), message].joined(separator: "\n")
    }
}
