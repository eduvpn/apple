//
//  Logger.swift
//  EduVPN
//
//  Copyright © 2021 The Commons Conservancy. All rights reserved.

import Foundation

class Logger {
    let maxLinesInMemory = 1000

    let logFileURL: URL?
    let separator: String

    var lines: [String] = []
    let dateFormatter: DateFormatter

    init(appGroup: String, separator: String, logFileName: String) {
        let parentURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
        let url = parentURL?.appendingPathComponent(logFileName)
        self.logFileURL = url
        self.separator = separator
        if let url = url {
            var logContentsInDisk = (try? String(contentsOf: url)) ?? ""
            if let separatorRange = logContentsInDisk.range(of: separator) {
                let discardableBounds = (lower: logContentsInDisk.startIndex, upper: separatorRange.upperBound)
                logContentsInDisk.removeSubrange(Range(uncheckedBounds: discardableBounds))
            }
            if !logContentsInDisk.isEmpty {
                lines = [logContentsInDisk]
                lines.append("\n")
                lines.append(separator)
                lines.append("\n")
            }
        }

        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    }

    func log(_ message: String) {
        let timestamp = dateFormatter.string(from: Date())
        let line = "\(timestamp) \(message)"
        NSLog("\(line)\n")
        if lines.count >= maxLinesInMemory {
            lines.removeFirst()
        }
        lines.append(line)
    }

    func flushToDisk() {
        log("Flushing log ...")
        if let url = logFileURL {
            let content = lines.joined(separator: "\n")
            do {
                try content.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                NSLog("Error writing WireGuard log to disk: \(error)")
            }
            lines = []
        }
    }
}
