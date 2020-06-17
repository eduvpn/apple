//
//  Multiplatform.swift
//  EduVPN
//
//  Created by Johan Kool on 28/05/2020.
//  Copyright © 2020 SURFNet. All rights reserved.
//

import Foundation

protocol Presenting {
    func present(_ viewControllerToPresent: ViewController, animated flag: Bool, completion: (() -> Void)?)
    func dismiss(animated flag: Bool, completion: (() -> Void)?)
}

protocol Navigating {
    func pushViewController(_ viewController: ViewController, animated: Bool)
    func popViewController(animated: Bool) -> ViewController?
    func popToRootViewController(animated: Bool) -> [ViewController]?
}


#if os(iOS)
import UIKit

typealias ApplicationDelegate = UIApplicationDelegate
typealias ViewController = UIViewController
typealias PresentingController = UIViewController
typealias NavigationController = UINavigationController
typealias Window = UIWindow
typealias Storyboard = UIStoryboard
typealias Button = UIButton
typealias Image = UIImage
typealias Label = UILabel
typealias ImageView = UIImageView
typealias Switch = UISwitch

extension PresentingController: Presenting { }
extension NavigationController: Navigating { }

#elseif os(macOS)
import AppKit

typealias ApplicationDelegate = NSApplicationDelegate
typealias ViewController = NSViewController
typealias Window = NSWindow
typealias Storyboard = NSStoryboard
typealias Button = NSButton
typealias Image = NSImage
typealias ImageView = NSImageView

extension Window {
    func makeKeyAndVisible() {
        makeKey()
    }
    
    var rootViewController: ViewController? {
        get {
            return windowController?.contentViewController
        }
    }
}

extension Storyboard {
    
    func instantiateInitialViewController() -> Any {
        return instantiateInitialController()
    }
    
    func instantiateViewController(withIdentifier identifier: SceneIdentifier) -> Any {
        return instantiateController(withIdentifier: identifier)
    }
}

class Label: NSTextField {
    
    var text: String? {
        get {
            return stringValue
        }
        set {
            stringValue = newValue ?? ""
        }
    }
}

class Switch: NSButton {
    
    var isOn: Bool {
        get {
            return self.state == .on
        }
        set {
            self.state = newValue ? .on : .off
        }
    }
   
}

#endif

