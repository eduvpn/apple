//
//  InstanceService.swift
//  EduVPN
//
//  Created by Jeroen Leenarts on 01-08-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

import Foundation
import Moya
import Result

struct DynamicInstanceService: TargetType {
    let baseURL: URL

    var path: String { return "/info.json" }
    var method: Moya.Method { return .get }

    var parameterEncoding: ParameterEncoding { return JSONEncoding.default }

    var task: Task { return .request }

    var sampleData: Data { return "".data(using: String.Encoding.utf8)! }

    var parameters: [String: Any]? {
            return nil
    }
}

//class DynamicInstanceProvider: MoyaProvider<DynamicInstanceService> {
//    let baseURL: URL
//
//    public init(baseURL: URL, endpointClosure: @escaping EndpointClosure = MoyaProvider.defaultEndpointMapping,
//                requestClosure: @escaping RequestClosure = MoyaProvider.defaultRequestMapping,
//                stubClosure: @escaping StubClosure = MoyaProvider.neverStub,
//                manager: Manager = MoyaProvider<DynamicInstanceService>.defaultAlamofireManager(),
//                plugins: [PluginType] = [],
//                trackInflights: Bool = false) {
//        self.baseURL = baseURL
//        super.init(endpointClosure: endpointClosure, requestClosure: requestClosure, stubClosure: stubClosure, manager: manager, plugins: plugins, trackInflights: trackInflights)
//
//    }
//
//    override func request(_ target: DynamicInstanceService, completion: @escaping Moya.Completion) -> Cancellable {
//        let dynamicTarget = DynamicInstanceService(baseURL: baseURL)
//        return super.request(dynamicTarget, completion: completion)
//    }
//}
