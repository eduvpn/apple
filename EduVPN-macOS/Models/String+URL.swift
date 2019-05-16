//
//  String+URL.swift
//  eduVPN
//
//  Created by Johan Kool on 07/07/2017.
//  Copyright © 2017-2019 Commons Conservancy.
//

import Foundation

extension String {
    
    /// Convenience method to convert string to URL
    ///
    /// - Parameter slash: Appends slash to URL if not present
    /// - Returns: URL
    func asURL(appendSlash slash: Bool = false) -> URL? {
        if slash && !hasSuffix("/") {
            return URL(string: self + "/")
        } else {
            return URL(string: self)
        }
    }
    
}
