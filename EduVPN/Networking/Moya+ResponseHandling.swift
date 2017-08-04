//
//  Moya+ResponseHandling.swift
//  EduVPN
//
//  Created by Jeroen Leenarts on 04-08-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

import Moya

let signedAtDateFormatter: DateFormatter = {
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return dateFormatter
}()

extension Moya.Response {
    func mapResponseToInstances() throws -> Instances? {
        let any = try self.mapJSON()
        guard let array = any as? [String: AnyObject] else {
            throw MoyaError.jsonMapping(self)
        }

        return Instances(json: array)
    }
}
