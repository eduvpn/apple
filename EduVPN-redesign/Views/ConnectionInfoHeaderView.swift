//
//  ConnectionInfoHeaderView.swift
//  EduVPN
//

#if os(macOS)
import AppKit

class ConnectionInfoHeaderView: NSView {

    // If set, passes button clicks to its button subview
    var isPassthroughToButtonEnabled = false

    override func mouseUp(with event: NSEvent) {
        if isPassthroughToButtonEnabled {
            if let buttonSubview = subviews.first(where: { $0 is NSButton }),
                let button = buttonSubview as? NSButton {
                button.cell?.performClick(self)
                return
            }
        }
        super.mouseUp(with: event)
    }
}

#endif
