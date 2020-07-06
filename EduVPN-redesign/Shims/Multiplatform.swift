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
typealias Image = UIImage
typealias Label = UILabel
typealias ImageView = UIImageView
typealias Switch = UISwitch
typealias StackView = UIStackView
typealias View = UIView

extension PresentingController: Presenting { }
extension NavigationController: Navigating { }

extension TableView {
    func dequeue<T: TableViewCell>(identifier: String, indexPath: IndexPath) -> T {
        //swiftlint:disable:next force_cast
        return dequeueReusableCell(withIdentifier: identifier, for: indexPath) as! T
    }
}

#elseif os(macOS)
import AppKit

typealias ApplicationDelegate = NSApplicationDelegate
typealias ViewController = NSViewController
typealias Window = NSWindow
typealias Storyboard = NSStoryboard
typealias Button = NSButton
typealias TableView = NSTableView
typealias TableViewCell = NSTableCellView
typealias Image = NSImage
typealias ImageView = NSImageView
typealias View = NSView

extension Window {
    func makeKeyAndVisible() {
        makeKey()
    }

    var rootViewController: ViewController? {
        return windowController?.contentViewController
    }
}

extension Storyboard {
    
    func instantiateInitialViewController() -> Any {
        return instantiateInitialController()!
    }
    
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
}

extension NSButton {
    
    enum Event {
        case touchUpInside
    }
    
    func addTarget(_ target: AnyObject?, action: Selector, for controlEvents: Event) {
        self.target = target
        self.action = action
    }
    
}

class Label: NSTextField {
    
    convenience init() {
        self.init(frame: .zero)
        self.isEditable = false
    }
    
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
    
    convenience init() {
        self.init(frame: .zero)
        self.setButtonType(.switch)
    }
    
    var isOn: Bool {
        get {
            return self.state == .on
        }
        set {
            self.state = newValue ? .on : .off
        }
    }
   
}

class StackView: NSStackView {
    
    convenience init(arrangedSubviews: [View]) {
        self.init(views: arrangedSubviews)
    }
    
}

extension Button {
    
    var isSelected: Bool {
        get {
            state == .on
        }
        set {
            state = newValue ? .on  : .off
        }
    }
}

#endif
