//
//  RootCoordinator.swift
//  eduVPN
//
//  Created by Jeroen Leenarts on 08-08-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

#if os(macOS)
import Cocoa
#endif
import Foundation
#if os(iOS)
import UIKit
#endif

public protocol RootViewControllerProvider: class {
    // The coordinators 'rootViewController'. It helps to think of this as the view
    // controller that can be used to dismiss the coordinator from the view hierarchy.
    
    #if os(iOS)
    
    var rootViewController: UIViewController { get }
    
    #elseif os(macOS)
    
    var windowController: NSWindowController { get }
    
    #endif
}

/// A Coordinator type that provides a root UIViewController
public typealias RootViewCoordinator = Coordinator & RootViewControllerProvider
