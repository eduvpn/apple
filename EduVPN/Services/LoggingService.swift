//
//  LoggingService.swift
//  EduVPN
//

import Foundation
import NetworkExtension
import PromiseKit

class LoggingService {

    private var logSeparator = "--- EOF ---"
    private var appLogStarter = "App:"
    private var tunnelLogStarter = "Tunnel:"
    private var logger: Logger?

    private let connectionService: ConnectionService

    init(connectionService: ConnectionService) {
        self.connectionService = connectionService
    }

    func appLog(_ message: String) {
        getLogger().log(message)
    }

    func closeLogFile() {
        getLogger().log(Logger.endOfAppLogMarker)
        self.logger = nil
    }

    func getLog() -> Promise<String?> {
        return connectionService.getConnectionLog()
    }

    private func getLogger() -> Logger {
        if let logger = self.logger {
            return logger
        } else {
            let appGroup: String = {
                let appBundleId = Bundle.main.bundleIdentifier ?? ""
                #if os(macOS)
                return "\((Bundle.main.infoDictionary?["AppIdentifierPrefix"] as? String) ?? "")group.\(appBundleId)"
                #elseif os(iOS)
                return "group.\(appBundleId)"
                #endif
            }()
            let logContainerDirectoryURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)!
            let logFileURL = logContainerDirectoryURL.appendingPathComponent("debug.log")
            let tempLogFileURL = logContainerDirectoryURL.appendingPathComponent("temp.log")
            let logger = Logger(appComponent: .containerApp, logFileURL: logFileURL, tempFileURL: tempLogFileURL,
                                shouldTruncateTillLogSeparator: false,
                                canAppendLogSeparatorOnInit: true)
            logger.logAppVersion()
            self.logger = logger
            return logger
        }
    }
}
