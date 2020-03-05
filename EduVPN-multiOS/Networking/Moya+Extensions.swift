//
//  Moya+Extensions.swift
//  eduVPN
//

import Foundation
import Moya

protocol AcceptJson {}

extension TargetType where Self: AcceptJson {
    
    var headers: [String: String]? {
        return ["Accept": "application/json"]
    }
}

protocol EmptySampleData {}

extension TargetType where Self: EmptySampleData {
    
    var sampleData: Data {
        return "".data(using: String.Encoding.utf8) ?? Data()
    }
}

public extension MoyaProvider {
    final class func ephemeralAlamofireManager() -> Manager {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpAdditionalHeaders = Manager.defaultHTTPHeaders

        let manager = Manager(configuration: configuration)
        manager.startRequestsImmediately = false
        return manager
    }
}
