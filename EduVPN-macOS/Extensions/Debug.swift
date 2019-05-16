//
//  Debug.swift
//  eduVPN
//
//  Created by Johan Kool on 16/08/2018.
//  Copyright © 2017-2019 Commons Conservancy.
//

import Foundation

func debugLog(_ items: Any...) {
    #if DEBUG
    print(items)
    #endif
}

