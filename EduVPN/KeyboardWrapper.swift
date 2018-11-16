//
//  KeyboardWrapper.swift
//  EduVPN
//
//  Created by Jeroen Leenarts on 06-11-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

import UIKit

/// Implement the method of this protocol to respond to `UIKeyboard` notifications.
public protocol KeyboardWrapperDelegate: class {

    /// Called when `KeyboardWrapper` will receive `UIKeyboard[WillShow|DidShow|WillHide|DidHide]Notification`.
    func keyboardWrapper(_ wrapper: KeyboardWrapper, didChangeKeyboardInfo info: KeyboardInfo)
}

/// Responsible for observing `UIKeyboard` notifications and calling `delegate` to notify about changes.
open class KeyboardWrapper {

    /// The delegate for keyboard notifications.
    open weak var delegate: KeyboardWrapperDelegate?

    /// Creates a new instance of `KeyboardWrapper` and adds itself as observer for `UIKeyboard` notifications.
    public init() {
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(keyboardWillShowNotification), name: UIResponder.keyboardWillShowNotification, object: nil)
        center.addObserver(self, selector: #selector(keyboardDidShowNotification), name: UIResponder.keyboardDidShowNotification, object: nil)
        center.addObserver(self, selector: #selector(keyboardWillHideNotification), name: UIResponder.keyboardWillHideNotification, object: nil)
        center.addObserver(self, selector: #selector(keyboardDidHideNotification), name: UIResponder.keyboardDidHideNotification, object: nil)
    }

    /// Creates a new instance of `KeyboardWrapper`, adds itself as observer for `UIKeyboard` notifications and
    /// sets `delegate`.
    ///  - parameter delegate: The delegate for the keyboard wrapper.
    public convenience init(delegate: KeyboardWrapperDelegate) {
        self.init()
        self.delegate = delegate
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc
    fileprivate dynamic func keyboardWillShowNotification(_ notification: Notification) {
        let info = KeyboardInfo.fromNotificationUserInfo((notification as NSNotification).userInfo, state: .willShow)
        delegate?.keyboardWrapper(self, didChangeKeyboardInfo: info)
    }

    @objc
    fileprivate dynamic func keyboardDidShowNotification(_ notification: Notification) {
        let info = KeyboardInfo.fromNotificationUserInfo((notification as NSNotification).userInfo, state: .visible)
        delegate?.keyboardWrapper(self, didChangeKeyboardInfo: info)
    }

    @objc
    fileprivate dynamic func keyboardWillHideNotification(_ notification: Notification) {
        let info = KeyboardInfo.fromNotificationUserInfo((notification as NSNotification).userInfo, state: .willHide)
        delegate?.keyboardWrapper(self, didChangeKeyboardInfo: info)
    }

    @objc
    fileprivate dynamic func keyboardDidHideNotification(_ notification: Notification) {
        let info = KeyboardInfo.fromNotificationUserInfo((notification as NSNotification).userInfo, state: .hidden)
        delegate?.keyboardWrapper(self, didChangeKeyboardInfo: info)
    }
}

/// Represents the keyboard state.
public enum KeyboardState {
    case hidden
    case willShow
    case visible
    case willHide
}

/// Represents info about keyboard extracted from `NSNotification`.
public struct KeyboardInfo {

    /// The state of the keyboard.
    public let state: KeyboardState

    /// The start frame of the keyboard in screen coordinates.
    /// Corresponds to `UIKeyboardFrameBeginUserInfoKey`.
    public let beginFrame: CGRect

    /// The end frame of the keyboard in screen coordinates.
    /// Corresponds to `UIKeyboardFrameEndUserInfoKey`.
    public let endFrame: CGRect

    /// Defines how the keyboard will be animated onto or off the screen.
    /// Corresponds to `UIKeyboardAnimationCurveUserInfoKey`.
    public let animationCurve: UIView.AnimationCurve

    /// The duration of the animation in seconds.
    /// Corresponds to `UIKeyboardAnimationDurationUserInfoKey`.
    public let animationDuration: TimeInterval

    /// Options for animating constructed from `animationCurve` property.
    public var animationOptions: UIView.AnimationOptions {
        switch animationCurve {
        case .easeInOut: return UIView.AnimationOptions()
        case .easeIn: return UIView.AnimationOptions.curveEaseIn
        case .easeOut: return UIView.AnimationOptions.curveEaseOut
        case .linear: return UIView.AnimationOptions.curveLinear
        }
    }

    /// Creates instance of `KeyboardInfo` using `userInfo` from `NSNotification` object and a keyboard state.
    /// If there is no info or `info` doesn't contain appropriate key-value pair uses default values.
    ///  - parameter info: The UserInfo object
    ///  - parameter state: The current state of the keyboard
    ///  - returns: `KeybiardInfo` object containing keyboard related info items.
    public static func fromNotificationUserInfo(_ info: [AnyHashable: Any]?,
                                                state: KeyboardState) -> KeyboardInfo {
        var beginFrame = CGRect.zero
        (info?[UIResponder.keyboardFrameBeginUserInfoKey] as AnyObject).getValue(&beginFrame)

        var endFrame = CGRect.zero
        (info?[UIResponder.keyboardFrameEndUserInfoKey] as AnyObject).getValue(&endFrame)

        let curve = UIView.AnimationCurve(rawValue: info?[UIResponder.keyboardAnimationCurveUserInfoKey] as? Int ?? 0) ?? .easeInOut
        let duration = TimeInterval(info?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.0)
        return KeyboardInfo(state: state, beginFrame: beginFrame, endFrame: endFrame, animationCurve: curve, animationDuration: duration)
    }
}
