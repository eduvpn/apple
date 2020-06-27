//
//  NavigationController.swift
//  EduVPN
//

protocol NavigationControllerDelegate: class {
    func addServerButtonClicked()
    // func preferencesButtonClicked()
    // func helpButtonClicked()
}

#if os(macOS)
import AppKit

class NavigationController: NSViewController {

    var environment: Environment?

    var isUserAllowedToGoBack: Bool = true {
        didSet {
            updateToolbarLeftButton()
        }
    }

    weak var delegate: NavigationControllerDelegate?

    private var canGoBack: Bool { children.count > 1 }

    private var cancelAuthorizationHandler: (() -> Void)?

    @IBOutlet weak var toolbarLeftButton: NSButton!

    @IBOutlet weak var authorizingMessageBox: NSBox!

    @IBAction func toolbarLeftButtonClicked(_ sender: Any) {
        if canGoBack {
            popViewController(animated: true)
        } else {
            delegate?.addServerButtonClicked()
        }
    }

    @IBAction func cancelAuthorizationButtonClicked(_ sender: Any) {
        cancelAuthorizationHandler?()
    }

    private func updateToolbarLeftButton() {
        let image = canGoBack ?
            NSImage(named: NSImage.goBackTemplateName)! : // swiftlint:disable:this force_unwrapping
            NSImage(named: NSImage.addTemplateName)! // swiftlint:disable:this force_unwrapping
        toolbarLeftButton.image = image
        toolbarLeftButton.isHidden = !authorizingMessageBox.isHidden ||
            (canGoBack && !isUserAllowedToGoBack)
    }
}

extension NavigationController: Navigating {

    func pushViewController(_ viewController: ViewController, animated: Bool) {
        guard let lastVC = children.last else { return }

        addChild(viewController)
        toolbarLeftButton.isEnabled = false
        transition(from: lastVC, to: viewController,
                   options: animated ? .slideForward : []) { [weak self] in
            guard let self = self else { return }
            self.updateToolbarLeftButton()
            self.toolbarLeftButton.isEnabled = true
        }
    }

    @discardableResult
    func popViewController(animated: Bool) -> ViewController? {
        precondition(children.count > 1)
        let lastVC = children[children.count - 1]
        let lastButOneVC = children[children.count - 2]

        toolbarLeftButton.isEnabled = false
        transition(from: lastVC, to: lastButOneVC,
                   options: animated ? .slideBackward : []) { [weak self] in
            guard let self = self else { return }
            lastVC.removeFromParent()
            self.isUserAllowedToGoBack = true
            self.updateToolbarLeftButton()
            self.toolbarLeftButton.isEnabled = true
        }

        return lastVC
    }
}

extension NavigationController {
    func showAuthorizingMessage(cancelAuthorizationHandler: @escaping () -> Void) {
        self.authorizingMessageBox.isHidden = false
        self.cancelAuthorizationHandler = cancelAuthorizationHandler
        self.updateToolbarLeftButton()
    }

    func hideAuthorizingMessage() {
        self.authorizingMessageBox.isHidden = true
        self.cancelAuthorizationHandler = nil
        self.updateToolbarLeftButton()
    }
}

#elseif os(iOS)

import UIKit

class NavigationController: UINavigationController {
    // Override push and pop to set navigation items
}

#endif
