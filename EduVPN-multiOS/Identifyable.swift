//
//  Identifyable.swift
//  eduVPN
//
//  Created by Jeroen Leenarts on 14-08-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

import Foundation

#if os(iOS)

import UIKit

#elseif os(macOS)
import Cocoa

#endif

public protocol Identifyable: class {
    static var identifier: String { get }
}

public extension Identifyable {
    
    static var identifier: String {
        return String(describing: Self.self)
    }
}

#if os(iOS)

extension UIStoryboard {

    public func instantiateViewController<T: Identifyable>(type: T.Type) -> T where T: UIViewController {
        return instantiateViewController(withIdentifier: type.identifier) as! T // swiftlint:disable:this force_cast
    }
}

#elseif os(macOS)

extension NSStoryboard {
    
    public func instantiateViewController<T: Identifyable>(type: T.Type) -> T where T: NSViewController {
        return instantiateController(withIdentifier: type.identifier) as! T // swiftlint:disable:this force_cast
    }
}

#endif
