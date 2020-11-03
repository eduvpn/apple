//
//  ConnectionViewModel+SupportContact.swift
//  EduVPN
//

import Foundation

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

extension ConnectionViewModel.SupportContact {
    var isEmpty: Bool {
        supportContact.isEmpty
    }

    var attributedString: NSAttributedString {
        if supportContact.isEmpty {
            return NSAttributedString(string: "")
        }
        #if os(macOS)
        let font = NSFont(name: "OpenSans-Regular", size: 14) ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let color = NSColor(named: "RegularUITextColor") ?? NSColor.labelColor
        #elseif os(iOS)
        let font = UIFont(name: "OpenSans-Regular", size: 14) ?? UIFont.systemFont(ofSize: 14)
        let color = UIColor(named: "RegularUITextColor") ?? UIColor.gray
        #endif
        let contactStrings: [NSAttributedString] = supportContact.map { urlString in
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
        let resultString = NSMutableAttributedString(
            string: "Support: ",
            attributes: [.font: font, .foregroundColor: color])
        for (index, contactString) in contactStrings.enumerated() {
            if index > 0 {
                let comma = NSAttributedString(
                    string: ", ",
                    attributes: [.font: font, .foregroundColor: color])
                resultString.append(comma)
            }
            resultString.append(contactString)
        }
        return resultString
    }
}
