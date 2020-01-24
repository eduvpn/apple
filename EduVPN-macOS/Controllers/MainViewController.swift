//
//  MainViewController.swift
//  eduVPN
//
//  Created by Johan Kool on 09/08/2017.
//  Copyright © 2017-2020 Commons Conservancy.
//

import Cocoa

class MainViewController: NSViewController {
    
    @IBOutlet var containerView: NSView!
    @IBOutlet weak var cancelButton: NSButton!
    @IBOutlet weak var activityIndicatorView: NSVisualEffectView!
    @IBOutlet weak var activityIndicator: NSProgressIndicator!
    @IBOutlet weak var activityLabel: NSTextField!
    
    var cancellable: Cancellable?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.wantsLayer = true
        activityIndicatorView.isHidden = true
    }
    
    func show(viewController: NSViewController,
              options: NSViewController.TransitionOptions = [],
              animated: Bool = true,
              completionHandler: (() -> Void)?) {
        
        let currentViewController = self.currentViewController
     
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
    
    var currentViewController: NSViewController {
        return children[0]
    }
    
    @IBAction func cancel(_ sender: Any) {
        cancellable?.cancel()
    }
    
}
