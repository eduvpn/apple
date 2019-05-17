//
//  MainWindowController.swift
//  eduVPN
//
//  Created by Johan Kool on 28/06/2017.
//  Copyright © 2017-2019 Commons Conservancy.
//

import Cocoa
import AppAuth

/// Does nothing but silence Xcode 9.1 warning
class MainWindow: NSWindow {
    
}

class MainWindowController: NSWindowController {

    private var navigationStackStack: [[NSViewController]] = [[]]
    private var navigationStack: [NSViewController] {
        get {
            return navigationStackStack.last!
        }
        set {
            navigationStackStack.removeLast()
            navigationStackStack.append(newValue)
        }
    }
    @IBOutlet var topView: NSBox!
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
//        window?.backgroundColor = .white
        
        // Disabled, clips
//        window?.titlebarAppearsTransparent = true
//        topView.frame = CGRect(x: 0, y: 539, width: 378, height: 60)
//        window?.contentView?.addSubview(topView)

        navigationStack.append(mainViewController.currentViewController)
        
        NotificationCenter.default.addObserver(self, selector: #selector(didStartAuthenticating(notification:)), name: AuthenticationService.authenticationStarted, object: ServiceContainer.authenticationService)
        NotificationCenter.default.addObserver(self, selector: #selector(didFinishAuthenticating(notification:)), name: AuthenticationService.authenticationFinished, object: ServiceContainer.authenticationService)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private var mainViewController: MainViewController {
        return contentViewController as! MainViewController
    }
    
    // MARK: - Navigation
    
    enum Presentation {
        case push
        case present
    }
    
    func show(viewController: NSViewController, presentation: Presentation, animated: Bool = true, completionHandler: (() -> ())? = nil) {
        switch presentation {
        case .push:
            push(viewController: viewController, animated: animated, completionHandler: completionHandler)
        case .present:
            present(viewController: viewController, animated: animated, completionHandler: completionHandler)
        }
    }
    
    func close(viewController: NSViewController, animated: Bool = true, completionHandler: (() -> ())? = nil) {
        if navigationStack.count > 1, navigationStack.last == viewController {
            pop(animated: animated, completionHandler: completionHandler)
        } else if navigationStackStack.count > 1, navigationStackStack.last!.last == viewController {
            dismiss(animated: animated, completionHandler: completionHandler)
        }
    }
        
    func push(viewController: NSViewController, animated: Bool = true, completionHandler: (() -> ())? = nil) {
        navigationStack.append(viewController)
        mainViewController.show(viewController: viewController, options: .slideForward, animated: animated, completionHandler: completionHandler)
    }
    
    func pop(animated: Bool = true, completionHandler: (() -> ())? = nil) {
        guard navigationStack.count > 1 else {
            return
        }
        navigationStack.removeLast()
        mainViewController.show(viewController: navigationStack.last!, options: .slideBackward, animated: animated, completionHandler: completionHandler)
    }
    
    func popToRoot(animated: Bool = true, completionHandler: (() -> ())? = nil) {
        guard navigationStack.count > 1 else {
            return
        }
        navigationStack = [navigationStack.first!]
        mainViewController.show(viewController: navigationStack.last!, options: .slideBackward, animated: animated, completionHandler: completionHandler)
    }
    
    func present(viewController: NSViewController, options: NSViewController.TransitionOptions = .slideUp, animated: Bool = true, completionHandler: (() -> ())? = nil) {
        navigationStackStack.append([viewController])
        mainViewController.show(viewController: viewController, options: options, animated: animated, completionHandler: completionHandler)
    }
    
    func dismiss(options: NSViewController.TransitionOptions = .slideDown, animated: Bool = true, completionHandler: (() -> ())? = nil) {
        guard navigationStackStack.count > 1 else {
            return
        }
        navigationStackStack.removeLast()
        mainViewController.show(viewController: navigationStack.last!, options: options, animated: animated, completionHandler: completionHandler)
    }
    
    // MARK: - Authenticating
    @objc private func didStartAuthenticating(notification: NSNotification) {
        let authenticatingViewController = storyboard!.instantiateController(withIdentifier: "Authenticating") as! AuthenticatingViewController
        present(viewController: authenticatingViewController)
    }
    
    @objc private func didFinishAuthenticating(notification: NSNotification) {
        if let success = notification.userInfo?["success"] as? Bool, success {
             dismiss()
        } else {
             dismiss()
        }
    }
    
    // MARK: - Switching to screens
    
    /// Prompts user to chose a connection type
    ///
    /// - Parameters:
    ///   - allowClose: Wether user may close screen
    ///   - animated: Wether to show with animation
    func showChooseConnectionType(allowClose: Bool, animated: Bool = true) {
        let chooseConnectionTypeViewController = storyboard!.instantiateController(withIdentifier: "ChooseConnectionType") as! ChooseConnectionTypeViewController
        chooseConnectionTypeViewController.allowClose = allowClose
        present(viewController: chooseConnectionTypeViewController, animated: animated)
    }

    /// Prompts user to chose a provider
    ///
    /// - Parameters:
    ///   - connectionType: Connection type for the providers
    ///   - providers: Providers to chose from
    ///   - animated: Wether to show with animation
    func showChooseProvider(for connectionType: ConnectionType, from providers: [Provider], animated: Bool = true) {
        let chooseProviderViewController = storyboard!.instantiateController(withIdentifier: "ChooseProvider") as! ChooseProviderViewController
        chooseProviderViewController.connectionType = connectionType
        chooseProviderViewController.providers = providers
        push(viewController: chooseProviderViewController, animated: animated)
    }
        
    /// Prompts user to choose a profile
    ///
    /// - Parameters:
    ///   - profiles: Profiles to chose from
    ///   - userInfo: User info
    ///   - animated: Wether to show with animation
    func showChooseProfile(from profiles: [Profile], userInfo: UserInfo, animated: Bool = true) {
        let chooseProfileViewController = storyboard!.instantiateController(withIdentifier: "ChooseProfile") as! ChooseProfileViewController
        chooseProfileViewController.profiles = profiles
        chooseProfileViewController.userInfo = userInfo
        push(viewController: chooseProfileViewController, animated: animated)
    }
    
    /// Shows and starts connection
    ///
    /// - Parameters:
    ///   - profile: Profile
    ///   - userInfo: User info
    ///   - animated: Wether to show with animation
    func showConnection(for profile: Profile, userInfo: UserInfo, animated: Bool = true) {
        let connectionViewController = storyboard!.instantiateController(withIdentifier: "Connection") as! ConnectionViewController
        connectionViewController.profile = profile
        connectionViewController.userInfo = userInfo
        push(viewController: connectionViewController, animated: animated) {
            connectionViewController.connect()
        }
    }
    
}

extension NSViewController {
    
    var mainWindowController: MainWindowController? {
        return (NSApp.delegate as! AppDelegate).mainWindowController
    }
    
}
