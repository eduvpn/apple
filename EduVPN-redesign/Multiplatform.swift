//
//  Multiplatform.swift
//  EduVPN
//
//  Created by Johan Kool on 28/05/2020.
//  Copyright © 2020 SURFNet. All rights reserved.
//

import Foundation

#if os(iOS)
import UIKit

typealias ApplicationDelegate = UIApplicationDelegate
typealias ViewController = UIViewController
typealias Window = UIWindow
typealias Storyboard = UIStoryboard

#elseif os(macOS)
import AppKit

typealias ApplicationDelegate = NSApplicationDelegate
typealias ViewController = NSViewController
typealias Window = NSWindow
typealias Storyboard = NSStoryboard

extension ViewController {
    
    func present(controller: ViewController, animated: Bool) {
        
    }
    
    func dismiss(animated: Bool, completion: (() -> Void)? = nil) {
        dismiss(animated: true) // TODO: Completio
    }

}

#endif
