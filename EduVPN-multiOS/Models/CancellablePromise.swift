//
//  CancellablePromise.swift
//  EduVPN
//
//  Created by Johan Kool on 07/11/2019.
//  Copyright © 2019 SURFNet. All rights reserved.
//

import Foundation
import PromiseKit

// From https://stackoverflow.com/a/48152280/60488
// and https://gist.github.com/EfraimB/3ac240fc6e65aa8835df073f68fe32d9

public protocol Cancellable: class {
    func cancel()
}

class PromiseCancelledError: CancellableError {
    var isCancelled: Bool {
        return true
    }
}

public class CancellablePromise<T>: Cancellable, Thenable, CatchMixin {

    var promise: Promise<T>!
    var resolver: Resolver<T>!
    var cancellable: Cancellable!

    init(resolver: ((Resolver<T>) throws -> Void)!, cancellable: Cancellable) {
        self.promise = Promise<T>(resolver: { otherResolver in
            self.resolver = otherResolver
            try resolver(otherResolver)
        })
        self.cancellable = cancellable
    }

    init(promise: Promise<T>, resolver: Resolver<T>, cancellable: Cancellable) {
        self.promise = promise
        self.resolver = resolver
        self.cancellable = cancellable
    }

    public func cancel() {
        guard promise.isPending else {
            return
        }
        resolver.reject(PromiseCancelledError())
        cancellable?.cancel()
    }

    var value: T? {
        return promise.value
    }
    
    public func pipe(to body: @escaping (PromiseKit.Result<T>) -> Void) {
        promise.pipe(to: body)
    }
    
    public var result: PromiseKit.Result<T>? {
        return promise.result
    }
    
    public func _map<U>( _ transform: @escaping (T) throws -> U) -> CancellablePromise<U> { //swiftlint:disable:this identifier_name
        
        return CancellablePromise<U>(resolver: { (otherResolver) in
            self.pipe(to: { (result) in
                otherResolver.resolve(result.map(transform))
            })
        }, cancellable: cancellable)
    }
}

extension PromiseKit.Result {
    
    func map<U>(_ transform: @escaping (T) throws -> U) -> PromiseKit.Result<U> {
        switch self {
        case .fulfilled(let value):
        do {
            let mappedValue = try transform(value)
            return PromiseKit.Result<U>.fulfilled(mappedValue)
        } catch let error {
            return PromiseKit.Result<U>.rejected(error)
        }
        case .rejected(let error):
            return PromiseKit.Result<U>.rejected(error)
        }
    }
    
}
