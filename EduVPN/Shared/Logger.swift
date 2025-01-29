//
//  Logger.swift
//  EduVPN
//
//  Copyright © 2021 The Commons Conservancy. All rights reserved.

import Foundation
import os.log
class Logger {

    enum AppComponent: String {
        case containerApp = "APP"
        case tunnelExtension = "TUN"
    }

    static let logSeparator = "--- EOF ---"
    static let endOfAppLogMarker = "End of app log"

    private let logFileURL: URL?
    private var logFileHandle: UnsafeMutablePointer<FILE>?
    private let dateFormatter: DateFormatter
    private let osLog: OSLog
    private var timer: DispatchSourceTimer?
    private var timerQueue: DispatchQueue
    private var fileQueue: DispatchQueue
    private var shouldWriteLogSeparatorBeforeNextLogEntry = false

    init(appComponent: Logger.AppComponent, logFileURL: URL, tempFileURL: URL, shouldTruncateTillLogSeparator: Bool, canAppendLogSeparatorOnInit: Bool) {
        self.logFileURL = logFileURL

        let appId = Bundle.main.bundleIdentifier ?? ""
        let osLog = OSLog(subsystem: appId, category: appComponent.rawValue)
        let timerQueue = DispatchQueue(label: "LoggerTimerQueue", qos: .background)
        let fileQueue = DispatchQueue(label: "LoggerFileQueue", qos: .background)

        if let (fileHandle, shouldAddLogSeparator) = Self.setup(osLog: osLog, fileQueue: fileQueue, logFileURL: logFileURL, tempFileURL: tempFileURL,
                                       shouldTruncateTillLogSeparator: shouldTruncateTillLogSeparator,
                                       canAppendLogSeparatorOnInit: canAppendLogSeparatorOnInit) {
            self.logFileHandle = fileHandle
            self.shouldWriteLogSeparatorBeforeNextLogEntry = shouldAddLogSeparator
            os_log("Writing log to file: %{public}@", log: osLog, logFileURL.path)
        } else {
            self.logFileHandle = nil
            os_log("Not writing log to file")
        }

        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        self.osLog = osLog
        self.timerQueue = timerQueue
        self.fileQueue = fileQueue
    }

    func log(_ message: String) {
        guard let logFileHandle = self.logFileHandle else {
            return
        }

        let timestamp = dateFormatter.string(from: Date())
        let line = "\(timestamp) \(message)\n"
        self.write(line, to: logFileHandle, osLog: self.osLog)

        os_log("%{public}@", log: self.osLog, message)

        // Flush to disk every 5 seconds
        if self.timer == nil {
            // We don't use an NSTimer here because:
            // https://developer.apple.com/forums/thread/687170
            let timer = DispatchSource.makeTimerSource(queue: self.timerQueue)
            timer.schedule(deadline: .now() + .seconds(5), leeway: .seconds(1))
            timer.setEventHandler { [weak self] in
                guard let self = self else { return }
                self.flush(logFileHandle)
                self.timer = nil
            }
            timer.resume()
            self.timer = timer
        }
    }

    func flush() {
        if let logFileHandle = self.logFileHandle {
            self.flush(logFileHandle)
        }
    }

    func logAppVersion() {
        var appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown version"
        if let appBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            appVersion += " (\(appBuild))"
        }
        log("App version: \(appVersion)")
        flush()
    }

    func getLines(completionHandler: @escaping ([String]) -> Void) {
        var lines: [String] = []
        if let logFilePath = self.logFileURL?.path {
            self.fileQueue.async {
                let logFileHandle = fopen(logFilePath, "r")

                var bufferPointer: UnsafeMutablePointer<CChar>?
                var bufferSize: Int = 0
                var bytesRead = 0

                repeat {
                    bytesRead = getline(&bufferPointer, &bufferSize, logFileHandle)
                    if bytesRead > 0, let bufferPointer = bufferPointer {
                        let line = String(cString: bufferPointer)
                        lines.append(line)
                    }
                } while (bytesRead > 0)

                completionHandler(lines)
            }
        } else {
            completionHandler([])
        }
    }

    deinit {
        if let logFileHandle = self.logFileHandle {
            log("Closing log file")
            self.close(logFileHandle)
        }
    }
}

private extension Logger {
    static func setup(osLog: OSLog, fileQueue: DispatchQueue, logFileURL: URL, tempFileURL: URL,
                      shouldTruncateTillLogSeparator: Bool,
                      canAppendLogSeparatorOnInit: Bool) -> (UnsafeMutablePointer<FILE>, Bool)? {
        var hasPreExistingLogEntries = false
        var lastTwoLines: [String] = []
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: logFileURL.path) {
            if shouldTruncateTillLogSeparator {
                (hasPreExistingLogEntries, lastTwoLines) = Self.truncateEarlyLogEntries(logFileURL: logFileURL, tempFileURL: tempFileURL, osLog: osLog)
            } else {
                (hasPreExistingLogEntries, lastTwoLines) = Self.detectExistingLogEntries(logFileURL: logFileURL)
            }
        }
        guard let fileHandle = fopen(logFileURL.path, "a") else {
            return nil
        }
        let hasEndOfAppLogMarker = lastTwoLines.contains(where: { $0.hasSuffix(Self.endOfAppLogMarker) })
        let shouldAddLogSeparator = hasPreExistingLogEntries && !hasEndOfAppLogMarker && canAppendLogSeparatorOnInit
        return (fileHandle, shouldAddLogSeparator)
    }

    static func write(_ message: String, to fileHandle: UnsafeMutablePointer<FILE>, osLog: OSLog, fileQueue: DispatchQueue) {
        if let cString = message.cString(using: .utf8) {
            let result = cString.withUnsafeBufferPointer { cStringPointer in
                fileQueue.sync {
                    fputs(cStringPointer.baseAddress, fileHandle)
                }
            }
            if result <= 0 {
                os_log("Error writing log message to file", log: osLog)
            }
        }
    }

    func write(_ message: String, to fileHandle: UnsafeMutablePointer<FILE>, osLog: OSLog) {
        if shouldWriteLogSeparatorBeforeNextLogEntry {
            os_log("Adding log separator to file", log: osLog)
            Self.write("\n\(Self.logSeparator)\n\n", to: fileHandle, osLog: osLog, fileQueue: fileQueue)
            shouldWriteLogSeparatorBeforeNextLogEntry = false
        }
        Self.write(message, to: fileHandle, osLog: osLog, fileQueue: self.fileQueue)
    }

    func close(_ fileHandle: UnsafeMutablePointer<FILE>) {
        _ = self.fileQueue.sync {
            fclose(fileHandle)
        }
    }

    func flush(_ fileHandle: UnsafeMutablePointer<FILE>) {
        _ = self.fileQueue.sync {
            fflush(fileHandle)
        }
    }

    @discardableResult
    static func truncateEarlyLogEntries(logFileURL: URL, tempFileURL: URL, osLog: OSLog) -> (Bool, [String]) {
        var tempFileHandle: UnsafeMutablePointer<FILE>?
        let logFileHandle = fopen(logFileURL.path, "r")

        var bufferPointer: UnsafeMutablePointer<CChar>?
        var bufferSize: Int = 0

        var bytesRead = 0
        var isLogSeparatorFound = false
        var isSkippingEmptyLinesSequence = false
        var tmpFileHasLogEntries = false
        var origFileHasLogEntries = false
        var lastTwoLines: [String] = []

        repeat {
            bytesRead = getline(&bufferPointer, &bufferSize, logFileHandle)
            if bytesRead > 0, let bufferPointer = bufferPointer {
                let line = String(cString: bufferPointer)

                let isEmptyLine = (line == "\n")
                if !isEmptyLine {
                    origFileHasLogEntries = true
                }
                if isSkippingEmptyLinesSequence {
                    if isEmptyLine {
                        continue
                    } else {
                        isSkippingEmptyLinesSequence = false
                    }
                }
                if isLogSeparatorFound {
                    if let tmpFileHandle = tempFileHandle {
                        fwrite(bufferPointer, bytesRead, 1, tmpFileHandle)
                        tmpFileHasLogEntries = true
                    }
                } else if line.hasPrefix(Self.logSeparator) {
                    isLogSeparatorFound = true
                    isSkippingEmptyLinesSequence = true
                    if tempFileHandle == nil {
                        tempFileHandle = fopen(tempFileURL.path, "w")
                    }
                }

                if lastTwoLines.count > 1 {
                    lastTwoLines.removeFirst(lastTwoLines.count - 1)
                }
                lastTwoLines.append(line)
            }
        } while (bytesRead > 0)

        if let logFileHandle = logFileHandle {
            fclose(logFileHandle)
        }
        if let tmpFileHandle = tempFileHandle {
            fclose(tmpFileHandle)
        }
        bufferPointer?.deallocate()

        if isLogSeparatorFound {
            os_log("Truncating log", log: osLog)
            let fileManager = FileManager.default
            do {
                try fileManager.removeItem(at: logFileURL)
            } catch {
                os_log("Error removing log at \"%{public}@\": %{public}@", log: osLog, logFileURL.path, error.localizedDescription)
                return (origFileHasLogEntries, lastTwoLines)
            }
            do {
                try fileManager.moveItem(at: tempFileURL, to: logFileURL)
            } catch {
                os_log("Error moving log at \"%{public}@\" to \"%{public}@\": %{public}@", log: osLog, tempFileURL.path, logFileURL.path, error.localizedDescription)
                return (false, lastTwoLines)
            }
            return (tmpFileHasLogEntries, lastTwoLines)
        } else {
            os_log("Not truncating log", log: osLog, logFileURL.path)
            return (origFileHasLogEntries, lastTwoLines)
        }
    }

    static func detectExistingLogEntries(logFileURL: URL) -> (Bool, [String]) {
        let logFileHandle = fopen(logFileURL.path, "r")

        var bufferPointer: UnsafeMutablePointer<CChar>?
        var bufferSize: Int = 0

        var bytesRead = 0
        var origFileHasLogEntries = false
        var lastTwoLines: [String] = []

        repeat {
            bytesRead = getline(&bufferPointer, &bufferSize, logFileHandle)
            if bytesRead > 0, let bufferPointer = bufferPointer {
                let line = String(cString: bufferPointer)

                let isEmptyLine = (line == "\n")
                if !isEmptyLine {
                    origFileHasLogEntries = true
                    if lastTwoLines.count > 1 {
                        lastTwoLines.removeFirst(lastTwoLines.count - 1)
                    }
                    lastTwoLines.append(line)
                }
            }
        } while (bytesRead > 0)

        return (origFileHasLogEntries, lastTwoLines)
    }
}
