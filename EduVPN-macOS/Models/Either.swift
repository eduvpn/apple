//
//  Either.swift
//  eduVPN
//
//  Created by Johan Kool on 04/07/2017.
//  Copyright © 2017-2019 Commons Conservancy.
//

import Foundation

/// Either one or the other
///
/// - left: Left with associated value
/// - right: Right with associated value
enum Either<T, V> {
    case left(T)
    case right(V)
}

/// Result: success or failure
///
/// - success: Success with associated value
/// - failure: Failure with associated error
enum Result<T> {
    case success(T)
    case failure(Error)
}
