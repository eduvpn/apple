//
//  Message.swift
//  eduVPN
//
//  Created by Johan Kool on 23/11/2017.
//  Copyright © 2017-2019 Commons Conservancy.
//

import Foundation

enum MessageType: String {
    case notification
    case motd
    case maintenance
}

enum MessageAudience {
    case system
    case user
}

struct Message {
    let type: MessageType
    let audience: MessageAudience
    let message: String
    let date: Date
    let beginDate: Date?
    let endDate: Date?
}
