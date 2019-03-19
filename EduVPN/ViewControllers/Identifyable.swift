//
//  Identifyable.swift
//  eduVPN
//
//  Created by Jeroen Leenarts on 14-08-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

import Foundation
import UIKit

public protocol Identifyable: class {
    static var identifier: String { get }
}

public extension Identifyable {
    static var identifier: String {
        return String(describing: Self.self)
    }
}

extension UIStoryboard {

    public func instantiateViewController<T: Identifyable>(type: T.Type) -> T where T: UIViewController {
        return self.instantiateViewController(withIdentifier: type.identifier) as! T // swiftlint:disable:this force_cast
    }
}
