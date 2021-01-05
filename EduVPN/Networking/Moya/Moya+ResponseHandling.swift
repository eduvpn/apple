//
//  Moya+ResponseHandling.swift
//  eduVPN
//

import Moya
import PromiseKit

extension Moya.Response {
    
    func mapResponse<T: Decodable>() -> Promise<T> {
        return Promise(resolver: { seal in
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let result = try decoder.decode(T.self, from: self.filterSuccessfulStatusCodes().data)
                seal.fulfill(result)
            } catch {
                seal.reject(error)
            }
        })
    }
}
