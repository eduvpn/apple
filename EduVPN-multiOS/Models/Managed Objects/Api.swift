//
//  Api.swift
//  eduVPN
//
//  Created by Jeroen Leenarts on 19-02-18.
//  Copyright © 2018 SURFNet. All rights reserved.
//

import Foundation
import CoreData

extension Api {
    
    static func upsert(with instanceInfoModel: InstanceInfoModel,
                       for instance: Instance,
                       on context: NSManagedObjectContext) -> Api {
        
        let api: Api
        let instance = context.object(with: instance.objectID) as? Instance
        if let instance = instance {
            let predicate = NSPredicate(format: "instance.baseUri == %@ AND apiBaseUri == %@",
                                        instance.baseUri!, instanceInfoModel.apiBaseUrl.absoluteString)
            
            api = try! Api.findFirstInContext(context, predicate: predicate)
                ?? Api(context: context)//swiftlint:disable:this force_try
        } else {
            api = Api(context: context)
        }

        instance?.authServer = AuthServer.upsert(with: instanceInfoModel, on: context)

        api.instance = instance
        api.apiBaseUri = instanceInfoModel.apiBaseUrl.absoluteString

        return api
    }
}
