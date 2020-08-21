//
//  SupportContactTextView.swift
//  EduVPN
//

#if os(macOS)
import AppKit

class SupportContactTextView: NSTextView {
    init(supportContact: ConnectionViewModel.SupportContact) {
        let textStorage = NSTextStorage(attributedString: Self.attributedString(from: supportContact))
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

    private static func attributedString(from supportContact: ConnectionViewModel.SupportContact) -> NSAttributedString {
        if supportContact.supportContact.isEmpty {
            return NSAttributedString(string: "")
        }
        let font = NSFont(name: "Open Sans Regular", size: 14) ?? NSFont()
        let contactStrings: [NSAttributedString] = supportContact.supportContact.map { urlString in
            guard let url = URL(string: urlString) else {
                return NSAttributedString(string: urlString, attributes: [.font: font])
            }
            if urlString.hasPrefix("mailto:") {
                return NSAttributedString(
                    string: String(urlString.suffix(urlString.count - "mailto:".count)),
                    attributes: [.link: url, .font: font])
            } else if urlString.hasPrefix("tel:") {
                return NSAttributedString(
                    string: String(urlString.suffix(urlString.count - "tel:".count)),
                    attributes: [.link: url, .font: font])
            } else {
                return NSAttributedString(
                    string: urlString,
                    attributes: [.link: url, .font: font])
            }
        }
        let resultString = NSMutableAttributedString(string: "")
        for (index, contactString) in contactStrings.enumerated() {
            if index > 0 {
                resultString.append(NSAttributedString(string: ", ", attributes: [.font: font]))
            }
            resultString.append(contactString)
        }
        return resultString
    }
}

#endif
