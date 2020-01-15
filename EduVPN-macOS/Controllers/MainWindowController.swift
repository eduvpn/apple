//
//  MainWindowController.swift
//  eduVPN
//
//  Created by Johan Kool on 28/06/2017.
//  Copyright © 2017-2019 Commons Conservancy.
//

import Cocoa

class MainWindowController: NSWindowController, NSWindowDelegate {
    
    var navigationStackStack: [[NSViewController]] = [[]]
    private var navigationStack: [NSViewController] {
        get {
            return navigationStackStack.last ?? []
        }
        set {
            navigationStackStack.removeLast()
            navigationStackStack.append(newValue)
        }
    }
    
    @IBOutlet var topView: NSBox!
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        // Disabled, clips
        //        window?.titlebarAppearsTransparent = true
        //        topView.frame = CGRect(x: 0, y: 539, width: 378, height: 60)
        //        window?.contentView?.addSubview(topView)
        
        navigationStack.append(mainViewController.currentViewController)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    var mainViewController: MainViewController {
        return contentViewController as! MainViewController  //swiftlint:disable:this force_cast
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if UserDefaults.standard.bool(forKey: "showInDock") {
            NSApp.terminate(nil)
            return false
        } else {
            return true
        }
    }
    
    // MARK: - Navigation
    
    enum Presentation {
        case push
        case present
    }
    
    func show(viewController: NSViewController,
              presentation: Presentation,
              animated: Bool = true,
              completionHandler: (() -> Void)? = nil) {
        
        switch presentation {
        case .push:
            push(viewController: viewController, animated: animated, completionHandler: completionHandler)
        case .present:
            present(viewController: viewController, animated: animated, completionHandler: completionHandler)
        }
    }
    
    func push(viewController: NSViewController, animated: Bool = true, completionHandler: (() -> Void)? = nil) {
        navigationStack.append(viewController)
        mainViewController.show(viewController: viewController,
                                options: .slideForward,
                                animated: animated,
                                completionHandler: completionHandler)
    }
    
    func pop(animated: Bool = true, completionHandler: (() -> Void)? = nil) {
        guard navigationStack.count > 1 else {
            assertionFailure("Failed to pop (1)")
            return
        }

        navigationStack.removeLast()
        guard let last = navigationStack.last else {
            assertionFailure("Failed to pop (2)")
            return
        }

        mainViewController.show(viewController: last,
                                options: .slideBackward,
                                animated: animated,
                                completionHandler: completionHandler)
    }
    
    func popToRoot(animated: Bool = true, completionHandler: (() -> Void)? = nil) {
        guard navigationStack.count > 1 else {
            assertionFailure("Failed to pop to root (1)")
            return
        }

        guard let root = navigationStack.first else {
            assertionFailure("Failed to pop to root (2)")
            return
        }
        
        navigationStack = [root]
        mainViewController.show(viewController: root,
                                options: .slideBackward,
                                animated: animated,
                                completionHandler: completionHandler)
    }
    
    func present(viewController: NSViewController,
                 options: NSViewController.TransitionOptions = .slideUp,
                 animated: Bool = true,
                 completionHandler: (() -> Void)? = nil) {
        
        navigationStackStack.append([viewController])
        mainViewController.show(viewController: viewController,
                                options: options,
                                animated: animated,
                                completionHandler: completionHandler)
    }
    
    func dismiss(options: NSViewController.TransitionOptions = .slideDown,
                 animated: Bool = true,
                 completionHandler: (() -> Void)? = nil) {
        
        guard navigationStackStack.count > 1 else {
            assertionFailure("Failed to pop to dismiss (1)")
            return
        }
        
        navigationStackStack.removeLast()
        
        guard let last = navigationStack.last else {
            assertionFailure("Failed to pop to dismiss (2)")
            return
        }
        mainViewController.show(viewController: last,
            options: options,
            animated: animated,
            completionHandler: completionHandler)
    }

}
