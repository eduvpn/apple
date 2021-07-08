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

protocol AuthorizingViewController: ViewController {
    func didBeginFetchingServerInfoForAuthorization(userCancellationHandler: (() -> Void)?)
    func didBeginAuthorization(macUserCancellationHandler: (() -> Void)?)
    func didEndAuthorization()
}

#if os(iOS)
import UIKit

typealias ApplicationDelegate = UIApplicationDelegate
typealias ViewController = UIViewController
typealias PresentingController = UIViewController
typealias Window = UIWindow
typealias View = UIView
typealias Storyboard = UIStoryboard
typealias Button = UIButton
typealias TableView = UITableView
typealias TableViewCell = UITableViewCell
typealias Image = UIImage
typealias StackView = UIStackView
typealias ImageView = UIImageView
typealias ProgressIndicator = UIActivityIndicatorView
typealias Label = UILabel
typealias TextField = UITextField
typealias TextView = UITextView
typealias Spinner = UIActivityIndicatorView

extension PresentingController: Presenting { }
extension NavigationController: Navigating { }

extension ViewController {
    func performWithAnimation(seconds: TimeInterval, animationBlock: @escaping () -> Void) {
        UIView.animate(withDuration: seconds, animations: animationBlock)
    }
}

extension View {
    func setLayerOpacity(_ opacity: Float) {
        layer.opacity = opacity
    }
}

extension UIButton {
    var isOn: Bool {
        get {
            isSelected
        }
        set(value) {
            isSelected = value
        }
    }
}

extension TableView {
    func dequeue<T: TableViewCell>(_ type: T.Type, identifier: String, indexPath: IndexPath) -> T {
        // swiftlint:disable:next force_cast
        return dequeueReusableCell(withIdentifier: identifier, for: indexPath) as! T
    }

    func performUpdates(deletedIndices: [Int], insertedIndices: [Int]) {
        UIView.setAnimationsEnabled(false)
        beginUpdates()
        deleteRows(at: deletedIndices.map { IndexPath(row: $0, section: 0) }, with: .none)
        insertRows(at: insertedIndices.map { IndexPath(row: $0, section: 0) }, with: .none)
        endUpdates()
        UIView.setAnimationsEnabled(true)
    }

    func reloadRows(indices: [Int]) {
        reloadRows(at: indices.map { IndexPath(row: $0, section: 0) }, with: .none)
    }
}

extension ProgressIndicator {
    func startAnimation(_ sender: Any?) {
        startAnimating()
    }

    func stopAnimation(_ sender: Any?) {
        stopAnimating()
    }
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
typealias Label = NSTextField
typealias TextField = NSTextField
typealias TextView = NSTextView
typealias Spinner = NSProgressIndicator

extension Window {
    func makeKeyAndVisible() {
        makeKey()
    }

    var rootViewController: ViewController? {
        return windowController?.contentViewController
    }
}

extension ViewController {
    func performWithAnimation(seconds: TimeInterval, animationBlock: @escaping () -> Void) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = seconds
            context.allowsImplicitAnimation = true
            animationBlock()
        }, completionHandler: nil)
    }
}

extension View {
    func setLayerOpacity(_ opacity: Float) {
        layer?.opacity = opacity
    }

    func layoutIfNeeded() {
        layoutSubtreeIfNeeded()
    }
}

extension Label {
    var text: String? {
        get { stringValue }
        set(value) { stringValue = value ?? "" }
    }
}

extension NSButton {
    var isOn: Bool {
        get {
            state == .on
        }
        set(value) {
            state = value ? .on : .off
        }
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

    func reloadRows(indices: [Int]) {
        reloadData(forRowIndexes: IndexSet(indices), columnIndexes: IndexSet([0]))
    }
}

#endif
