//
//  Moya+Extensions.swift
//  eduVPN
//

import Foundation
import Moya
import Alamofire

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

extension MoyaProvider {
    final class func ephemeralAlamofireSession() -> Session {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.headers = .default

        return Session(configuration: configuration, startRequestsImmediately: false)
    }
}
