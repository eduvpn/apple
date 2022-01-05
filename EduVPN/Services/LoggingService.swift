//
//  LoggingService.swift
//  EduVPN
//

import Foundation
import NetworkExtension
import PromiseKit

class LoggingService {

    private let logFileURL: URL? = {
        let appGroup: String = {
            let appBundleId = Bundle.main.bundleIdentifier ?? ""
            #if os(macOS)
            return "\((Bundle.main.infoDictionary?["AppIdentifierPrefix"] as? String) ?? "")group.\(appBundleId)"
            #elseif os(iOS)
            return "group.\(appBundleId)"
            #endif
        }()
        let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
        return appGroupURL?.appendingPathComponent("debug.log")
    }()
    private let maxLogLines = 1000

    private var logLines: [String]
    private let dateFormatter: DateFormatter
    private var logSeparator = "--- EOF ---"
    private var appLogStarter = "App:"
    private var tunnelLogStarter = "Tunnel:"

    private let connectionService: ConnectionService

    init(connectionService: ConnectionService) {
        self.connectionService = connectionService
        self.logLines = []
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        self.dateFormatter = dateFormatter
    }

    func appLog(_ message: String, printToConsole: Bool = true) {
        let timestamp = dateFormatter.string(from: Date())
        let line = "\(timestamp) \(message)"
        if printToConsole {
            NSLog(message)
        }
        if logLines.count >= maxLogLines {
            logLines.removeFirst()
        }
        if logLines.isEmpty {
            logLines.append(appLogStarter)
        }
        logLines.append(line)
    }

    func logAppVersion() {
        var appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown version"
        if let appBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            appVersion += " (\(appBuild))"
        }
        appLog("App version: \(appVersion)", printToConsole: false)
    }

    func flushLogToDisk() {
        appLog("Flushing app log to disk ...")

        if let url = logFileURL {
            let content = logLines.joined(separator: "\n")
            let data = content.data(using: .utf8)
            if FileManager.default.fileExists(atPath: url.path) {
                do {
                    let fileHandle = try FileHandle(forWritingTo: url)
                    if let data = data {
                        fileHandle.seekToEndOfFile()
                        if let newLines = "\n\n".data(using: .utf8) {
                            fileHandle.write(newLines)
                        }
                        fileHandle.write(data)
                        fileHandle.closeFile()
                    }
                } catch {
                    NSLog("Error appending app log to disk: \(error)")
                }
            } else {
                do {
                    try content.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    NSLog("Error creating app log on disk: \(error)")
                }
            }
            logLines = []
        }
    }

    func getLog() -> Promise<String?> {
        firstly {
            connectionService.getConnectionLog()
        }.map { [weak self] logContent in
            guard let self = self else { return nil }
            return (logContent ?? "") + self.logLines.joined(separator: "\n")
        }
    }
}
