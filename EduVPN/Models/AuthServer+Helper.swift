//
//  AuthServer+Helper.swift
//  eduVPN
//
//  Created by Jeroen Leenarts on 25-02-18.
//  Copyright © 2018 SURFNet. All rights reserved.
//

import Foundation
import CoreData

extension AuthServer {
    static func upsert(with instanceInfoModel: InstanceInfoModel, on context: NSManagedObjectContext) -> AuthServer? {
        let tokenEndpoint = instanceInfoModel.tokenEndpoint.absoluteString
        let authorizationEndpoint = instanceInfoModel.authorizationEndpoint.absoluteString
        return upsert(tokenEndpoint: tokenEndpoint, authorizationEndpoint: authorizationEndpoint, on: context)
    }

    static func upsert(with instances: InstancesModel, on context: NSManagedObjectContext) -> AuthServer? {
        guard let tokenEndpoint = instances.tokenEndpoint?.absoluteString, let authorizationEndpoint = instances.authorizationEndpoint?.absoluteString else { return nil }
        return upsert(tokenEndpoint: tokenEndpoint, authorizationEndpoint: authorizationEndpoint, on: context)
    }

    static func upsert(tokenEndpoint: String, authorizationEndpoint: String, on context: NSManagedObjectContext) -> AuthServer {
        let authServer = try! AuthServer.findFirstInContext(context, predicate: NSPredicate(format: "authorizationEndpoint == %@ AND tokenEndpoint == %@", authorizationEndpoint, tokenEndpoint)) ?? AuthServer(context: context)//swiftlint:disable:this force_try
        authServer.authorizationEndpoint = authorizationEndpoint
        authServer.tokenEndpoint = tokenEndpoint

        return authServer
    }

}
