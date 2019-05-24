//
//  Moya+Promise.swift
//  eduVPN
//
//  Created by Jeroen Leenarts on 01-08-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

import Moya
import PromiseKit

public extension MoyaProvider {

    typealias PendingRequestPromise = (promise: Promise<Moya.Response>, cancellable: Cancellable)

    func request(target: Target,
                 queue: DispatchQueue? = nil,
                 progress: Moya.ProgressBlock? = nil) -> Promise<Moya.Response> {
        
        return requestCancellable(target: target,
                                  queue: queue,
                                  progress: progress).promise
    }

    func requestCancellable(target: Target,
                            queue: DispatchQueue?,
                            progress: Moya.ProgressBlock? = nil) -> PendingRequestPromise {
        
        let pending = Promise<Moya.Response>.pending()
        let completion = promiseCompletion(fulfill: pending.resolver.fulfill, reject: pending.resolver.reject)
        let cancellable = request(target, callbackQueue: queue, progress: progress, completion: completion)

        return (pending.promise, cancellable)
    }

    private func promiseCompletion(fulfill: @escaping (Moya.Response) -> Void,
                                   reject: @escaping (Swift.Error) -> Void) -> Moya.Completion {
        
        return { result in
            switch result {
                
            case let .success(response):
                fulfill(response)
                
            case let .failure(error):
                reject(error)
                
            }
        }
    }
}
