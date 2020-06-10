//
//  PresentingController.swift
//  eduVPN
//

import Cocoa

class PresentingController: NSViewController, Presenting {
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    func present(_ viewControllerToPresent: ViewController, animated flag: Bool, completion: (() -> Void)?) {
        
        navigationStackStack.append([viewControllerToPresent])
        show(viewController: viewControllerToPresent,
             options: .slideUp,
             animated: flag,
             completionHandler: completion)
    }
    
    func dismiss(animated flag: Bool, completion: (() -> Void)?) {
        guard navigationStackStack.count > 1 else {
            assertionFailure("Failed to pop to dismiss (1)")
            return
        }
        
        navigationStackStack.removeLast()
        
        guard let last = navigationStack.last else {
            assertionFailure("Failed to pop to dismiss (2)")
            return
        }
        show(viewController: last,
             options: .slideDown,
             animated: flag,
             completionHandler: completion)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.wantsLayer = true
    }

    fileprivate func show(viewController: NSViewController,
              options: NSViewController.TransitionOptions = [],
              animated: Bool = true,
              completionHandler: (() -> Void)?) {

        guard let currentViewController = self.currentViewController else {
            return
        }

        if !children.contains(viewController) {
            addChild(viewController)
        }

        // Ensure the layer is available
        currentViewController.view.superview?.wantsLayer = true

        if animated {
            assert(currentViewController.view.superview != nil)
            transition(from: currentViewController, to: viewController, options: options) {
                currentViewController.removeFromParent()
                completionHandler?()
            }
        } else {
            assert(currentViewController.view.superview != nil)
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0
                transition(from: currentViewController, to: viewController, options: options) {
                    currentViewController.removeFromParent()
                    completionHandler?()
                }
            }, completionHandler: nil)
        }
    }

    fileprivate var currentViewController: NSViewController? {
        return children.last ?? view.window?.contentViewController
    }

    fileprivate var navigationStackStack: [[NSViewController]] = [[]]
    fileprivate var navigationStack: [NSViewController] {
        get {
            return navigationStackStack.last ?? []
        }
        set {
            navigationStackStack.removeLast()
            navigationStackStack.append(newValue)
        }
    }

}

class NavigationController: PresentingController, Navigating {
      
    override func viewDidLoad() {
        super.viewDidLoad()
        if let currentViewController = currentViewController {
            navigationStack = [currentViewController]
        }
    }
    
    func pushViewController(_ viewController: ViewController, animated: Bool) {
        navigationStack.append(viewController)
        show(viewController: viewController,
             options: .slideForward,
             animated: animated,
             completionHandler: nil)
    }
    
    func popViewController(animated: Bool) -> ViewController? {
        guard navigationStack.count > 1 else {
            assertionFailure("Failed to pop (1)")
            return nil
        }
        
        navigationStack.removeLast()
        guard let last = navigationStack.last else {
            assertionFailure("Failed to pop (2)")
            return nil
        }
        
        show(viewController: last,
             options: .slideBackward,
             animated: animated,
             completionHandler: nil)
        return last
    }
    
    func popToRootViewController(animated: Bool) -> [ViewController]? {
        guard navigationStack.count > 1 else {
            return nil
        }
        
        guard let root = navigationStack.first else {
            assertionFailure("Failed to pop to root (2)")
            return nil
        }
        
        let allButRoot = Array(navigationStack[1...])
        
        navigationStack = [root]
        show(viewController: root,
             options: .slideBackward,
             animated: animated,
             completionHandler: nil)
        
        return allButRoot
    }
    
    var viewControllers: [ViewController] {
        get {
            return navigationStack
        }
        set {
            pushViewController(newValue[0], animated: false)
            navigationStack = newValue
        }
    }
    
}
