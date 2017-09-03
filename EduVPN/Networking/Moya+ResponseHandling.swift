//
//  Moya+ResponseHandling.swift
//  EduVPN
//
//  Created by Jeroen Leenarts on 04-08-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

import Moya
import PromiseKit

let signedAtDateFormatter: DateFormatter = {
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return dateFormatter
}()

extension Moya.Response {
    func mapResponseToInstances(providerType: ProviderType) -> Promise<InstancesModel> {
        return Promise(resolvers: { fulfill, reject in
            let any = try self.mapJSON()
            guard let dictionary = any as? [String: AnyObject] else {
                reject(MoyaError.jsonMapping(self))
                return
            }
            guard let obj = InstancesModel(json: dictionary, providerType: providerType) else {
                reject(MoyaError.jsonMapping(self))
                return
            }

            fulfill(obj)
        })
    }

    func mapResponseToInstanceInfo() -> Promise<InstanceInfoModel> {
        return Promise(resolvers: { fulfill, reject in
            let any = try self.mapJSON()
            guard let dictionary = any as? [String: AnyObject] else {
                reject(MoyaError.jsonMapping(self))
                return
            }
            guard let obj = InstanceInfoModel(json: dictionary) else {
                reject(MoyaError.jsonMapping(self))
                return
            }

            fulfill(obj)
        })
    }

    func mapResponseToProfiles() -> Promise<ProfilesModel> {
        return Promise(resolvers: { fulfill, reject in
            let any = try self.mapJSON()
            guard let dictionary = any as? [String: AnyObject] else {
                reject(MoyaError.jsonMapping(self))
                return
            }
            guard let obj = ProfilesModel(json: dictionary) else {
                reject(MoyaError.jsonMapping(self))
                return
            }

            fulfill(obj)
        })
    }
}
