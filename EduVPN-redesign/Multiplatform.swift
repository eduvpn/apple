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
//    init(rootViewController: ViewController)
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

extension PresentingController: Presenting { }
extension NavigationController: Navigating { }

#elseif os(macOS)
import AppKit

typealias ApplicationDelegate = NSApplicationDelegate
typealias ViewController = NSViewController
typealias Window = NSWindow
typealias Storyboard = NSStoryboard

extension Window {
    func makeKeyAndVisible() {
        makeKey()
    }
    
    var rootViewController: ViewController? {
        get {
            return windowController?.contentViewController
        }
        set {
//            (windowController as! MainWindowController).show(viewController: newValue!, presentation: .present, animated: false)
        }
    }
}

extension Storyboard {
    
    func instantiateViewController(withIdentifier identifier: SceneIdentifier) -> Any {
        return instantiateController(withIdentifier: identifier)
    }
}

#endif



