//
//  Logger.swift
//  EduVPN
//
//  Copyright © 2021 The Commons Conservancy. All rights reserved.

import Foundation
import OSLog

class Logger {
    let maxLinesInMemory = 1000

    let logFileURL: URL?

    private(set) var lines: [String]
    private let dateFormatter: DateFormatter
    private let oslog: OSLog

    init(appGroup: String, logSeparator: String, isStartedByApp: Bool, logFileName: String) {
        let parentURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
        let url = parentURL?.appendingPathComponent(logFileName)
        self.logFileURL = url
        if let url = url {
            var existingLog = (try? String(contentsOf: url))?.components(separatedBy: "\n") ?? []
            if let index = existingLog.firstIndex(of: logSeparator) {
                existingLog.removeFirst(index + 2)
            }
            if isStartedByApp,
               let appLogStartIndex = Self.indexOfTrailingAppLog(
                    in: existingLog, appSeparator: "App:", otherSeparators: ["Tunnel:", logSeparator]) {
                if appLogStartIndex > 0 {
                    existingLog.insert(contentsOf: [logSeparator, ""], at: appLogStartIndex)
                }
                existingLog.append("")
                existingLog.append("Tunnel:")
            } else if !existingLog.isEmpty {
                existingLog.append("")
                existingLog.append(logSeparator)
                existingLog.append("")
            }
            lines = existingLog
        } else {
            lines = []
        }

        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"

        var bundleIdComponents = (Bundle.main.bundleIdentifier ?? "UnknownBundleId").split(separator: ".")
        if bundleIdComponents.last == "TunnelExtension" {
            bundleIdComponents.removeLast()
            let appBundleId = String(bundleIdComponents.joined(separator: "."))
            oslog = OSLog(subsystem: appBundleId, category: "Tunnel")
        } else {
            let appBundleId = String(bundleIdComponents.joined(separator: "."))
            oslog = OSLog(subsystem: appBundleId, category: "App")
        }
    }

    private static func indexOfTrailingAppLog(in lines: [String], appSeparator: String, otherSeparators: [String]) -> Int? {
        for index in stride(from: lines.count - 1, through: 0, by: -1) {
            let line = lines[index]
            if line == appSeparator {
                return index
            }
            if otherSeparators.contains(line) {
                return nil
            }
        }
        return nil
    }

    func log(_ message: String) {
        let timestamp = dateFormatter.string(from: Date())
        let line = "\(timestamp) \(message)"
        os_log("%{public}@", log: oslog, type: .info, message)
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

    func logAppVersion() {
        var appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown version"
        if let appBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            appVersion += " (\(appBuild))"
        }
        log("App version: \(appVersion)")
    }
}
