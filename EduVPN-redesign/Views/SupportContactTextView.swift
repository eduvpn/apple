//
//  SupportContactTextView.swift
//  EduVPN
//

#if os(macOS)
import AppKit

class SupportContactTextView: NSTextView {
    init(supportContact: ConnectionViewModel.SupportContact) {
        let textStorage = NSTextStorage(attributedString: supportContact.attributedString)
        let textContainer = NSTextContainer()
        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 0), textContainer: textContainer)
        isSelectable = true
        isEditable = false
        allowsUndo = false
        isAutomaticSpellingCorrectionEnabled = false
        isAutomaticDataDetectionEnabled = false
        isAutomaticLinkDetectionEnabled = false
        isAutomaticTextCompletionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticQuoteSubstitutionEnabled = false
        backgroundColor = NSColor.windowBackgroundColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        guard let layoutManager = layoutManager, let textContainer = textContainer else {
            return .zero
        }
        layoutManager.ensureLayout(for: textContainer)
        return layoutManager.usedRect(for: textContainer).size
    }
}

#endif
