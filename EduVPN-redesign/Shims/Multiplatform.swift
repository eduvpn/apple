//
//  Multiplatform.swift
//  EduVPN
//
//  Created by Johan Kool on 28/05/2020.
//

import Foundation

protocol Presenting {
    func present(_ viewControllerToPresent: ViewController, animated flag: Bool, completion: (() -> Void)?)
    func dismiss(animated flag: Bool, completion: (() -> Void)?)
}

protocol Navigating {
    func pushViewController(_ viewController: ViewController, animated: Bool)
    func popViewController(animated: Bool) -> ViewController?
}

#if os(iOS)
import UIKit

typealias ApplicationDelegate = UIApplicationDelegate
typealias ViewController = UIViewController
typealias PresentingController = UIViewController
typealias Window = UIWindow
typealias Storyboard = UIStoryboard
typealias Button = UIButton
typealias TableView = UITableView
typealias TableViewCell = UITableViewCell
typealias Image = UIImage
typealias StackView = UIStackView
typealias ImageView = UIImageView
typealias ProgressIndicator = UIActivityIndicatorView

extension PresentingController: Presenting { }
extension NavigationController: Navigating { }

extension TableView {
    func dequeue<T: TableViewCell>(identifier: String, indexPath: IndexPath) -> T {
        //swiftlint:disable:next force_cast
        return dequeueReusableCell(withIdentifier: identifier, for: indexPath) as! T
    }
}

protocol AuthorizingViewController: ViewController {
}

#elseif os(macOS)
import AppKit

typealias ApplicationDelegate = NSApplicationDelegate
typealias ViewController = NSViewController
typealias Window = NSWindow
typealias View = NSView
typealias Storyboard = NSStoryboard
typealias Button = NSButton
typealias TableView = NSTableView
typealias TableViewCell = NSTableCellView
typealias Image = NSImage
typealias StackView = NSStackView
typealias ImageView = NSImageView
typealias ProgressIndicator = NSProgressIndicator

extension Window {
    func makeKeyAndVisible() {
        makeKey()
    }

    var rootViewController: ViewController? {
        return windowController?.contentViewController
    }
}

extension Storyboard {

    func instantiateViewController(withIdentifier identifier: SceneIdentifier) -> Any {
        return instantiateController(withIdentifier: identifier)
    }

    @available(OSX 10.15, *)
    func instantiateViewController<Controller>(identifier: SceneIdentifier, creator: ((NSCoder) -> Controller?)? = nil) -> Controller
        where Controller: ViewController {
            return instantiateController(identifier: identifier, creator: creator)
    }

}

extension TableView {
    func dequeue<T: TableViewCell>(_ type: T.Type, identifier: String, indexPath: IndexPath) -> T {
        guard let cellView = makeView(
            withIdentifier: NSUserInterfaceItemIdentifier(identifier),
            owner: self) else {
                fatalError("Can't dequeue \(T.self) with identifier \(identifier)")
        }
        return cellView as! T // swiftlint:disable:this force_cast
    }

    func performUpdates(deletedIndices: [Int], insertedIndices: [Int]) {
        beginUpdates()
        removeRows(at: IndexSet(deletedIndices), withAnimation: [])
        insertRows(at: IndexSet(insertedIndices), withAnimation: [])
        endUpdates()
    }
}

protocol AuthorizingViewController: ViewController {
    func showAuthorizingMessage(onCancelled: @escaping () -> Void)
    func hideAuthorizingMessage()
}

#endif
