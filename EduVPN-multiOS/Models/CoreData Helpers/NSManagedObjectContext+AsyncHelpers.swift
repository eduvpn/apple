//
//  NSManagedObjectContext+AsyncHelpers.swift
//  EduVPN
//
//  Created by Jeroen Leenarts on 08/04/2019.
//  Copyright © 2019 SURFNet. All rights reserved.
//

import CoreData
import Swift

extension NSManagedObjectContext {
    /**
     Synchronously executes a given function on the receiver’s queue.
     You use this method to safely address managed objects on a concurrent
     queue.
     - attention: This method may safely be called reentrantly.
     - parameter body: The method body to perform on the reciever.
     - returns: The value returned from the inner function.
     - throws: Any error thrown by the inner function. This method should be
     technically `rethrows`, but cannot be due to Swift limitations.
     **/
    public func performAndWaitOrThrow<Return>(_ body: () throws -> Return) rethrows -> Return {
        #if swift(>=3.1)
        return try withoutActuallyEscaping(body) { (work) in
            var result: Return!
            var error: Error?

            performAndWait {
                do {
                    result = try work()
                } catch let workError {
                    error = workError
                }
            }

            if let error = error {
                throw error
            } else {
                return result
            }
        }
        #else
        func impl(execute work: () throws -> Return, recover: (Error) throws -> Void) rethrows -> Return {
            var result: Return!
            var error: Error?

            // performAndWait is marked @escaping as of iOS 10.0.
            typealias Fn = (() -> Void) -> Void // swiftlint:disable:this nesting
            let performAndWaitNoescape = unsafeBitCast(self.performAndWait, to: Fn.self)
            performAndWaitNoescape {
                do {
                    result = try work()
                } catch let workError {
                    error = workError
                }
            }

            if let error = error {
                try recover(error)
            }

            return result
        }

        return try impl(execute: body, recover: { throw $0 })
        #endif
    }
}
