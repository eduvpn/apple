//
//  PacketTunnelProvider.swift
//  EduVPNTunnelExtension-macOS
//

import TunnelKitOpenVPNAppExtension
import TunnelKitOpenVPNManager
import TunnelKitOpenVPNCore
import TunnelKitAppExtension
import NetworkExtension
import SwiftyBeaver

#if os(macOS)
enum PacketTunnelProviderError: Error {
    case connectionAttemptFromOSNotAllowed
}
#endif

class PacketTunnelProvider: OpenVPNTunnelProvider {

    var connectedDate: Date?

    override var reasserting: Bool {
        didSet {
            #if os(macOS)
            if reasserting {
                if let tunnelProtocol = protocolConfiguration as? NETunnelProviderProtocol {
                    if tunnelProtocol.shouldPreventAutomaticConnections {
                        stopTunnel(with: .none, completionHandler: {})
                    }
                }
            }
            #endif
            if reasserting {
                connectedDate = nil
            } else {
                connectedDate = Date()
            }
        }
    }

    override func startTunnel(options: [String: NSObject]? = nil, completionHandler: @escaping (Error?) -> Void) {
        let startTunnelOptions = StartTunnelOptions(options: options ?? [:])

        #if os(macOS)
        if !startTunnelOptions.isStartedByApp {
            if let tunnelProtocol = protocolConfiguration as? NETunnelProviderProtocol {
                if tunnelProtocol.shouldPreventAutomaticConnections {
                    Darwin.sleep(3) // Prevent rapid connect-disconnect cycles
                    completionHandler(PacketTunnelProviderError.connectionAttemptFromOSNotAllowed)
                    return
                }
            }
        }
        #endif

        var appVersionString = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown version"
        if let appBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            appVersionString += " (\(appBuild))"
        }
        appVersion = appVersionString

        super.startTunnel(options: options) { [weak self] error in
            if startTunnelOptions.isStartedByApp {
                self?.rewriteLog(useDiskLog: error != nil)
            }
            self?.connectedDate = Date()
            completionHandler(error)
        }
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)? = nil) {
        // Convert TunnelKit's response to our response
        guard messageData.count == 1, let code = TunnelMessageCode(rawValue: messageData[0]) else {
            completionHandler?(nil)
            return
        }

        let encoder = JSONEncoder()
        switch code {
        case .getTransferredByteCount:
            super.handleAppMessage(
                OpenVPNProvider.Message.dataCount.data,
                completionHandler: completionHandler)
        case .getNetworkAddresses:
            super.handleAppMessage(OpenVPNProvider.Message.serverConfiguration.data) { data in
                guard let data = data else {
                    completionHandler?(nil)
                    return
                }
                var addresses: [String] = []
                if let config = try? JSONDecoder().decode(OpenVPN.Configuration.self, from: data) {
                    if let ipv4Address = config.ipv4?.address {
                        addresses.append(ipv4Address)
                    }
                    if let ipv6Address = config.ipv6?.address {
                        addresses.append(ipv6Address)
                    }
                }
                completionHandler?(try? encoder.encode(addresses))
            }
        case .getLog:
            super.handleAppMessage(
                OpenVPNProvider.Message.requestLog.data,
                completionHandler: completionHandler)
        case .getConnectedDate:
            completionHandler?(self.connectedDate?.toData())
        }
    }
}

private extension PacketTunnelProvider {
    func rewriteLog(useDiskLog: Bool) {
        if useDiskLog {
            moveUpLastLogSeparatorInDiskLog()
        } else {
            moveUpLastLogSeparatorInMemoryLog()
        }
    }

    func moveUpLastLogSeparatorInDiskLog() {
        // If there was an error during startTunnel, the log would've been already written to disk.
        // In that case, we should read the log on disk and modify that.
        let debugLogFilename = "debug.log"
        guard let tunnelProtocol = protocolConfiguration as? NETunnelProviderProtocol,
           let providerConfiguration = tunnelProtocol.providerConfiguration,
              let appGroup = try? OpenVPNProvider.Configuration.appGroup(from: providerConfiguration),
           let parentURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
               return
        }
        let debugLogURL = parentURL.appendingPathComponent(debugLogFilename)

        if let logString = try? String(contentsOf: debugLogURL) {
            var logLines = logString.components(separatedBy: "\n")
            if moveUpLastLogSeparator(in: &logLines) {
                let content = logLines.joined(separator: "\n")
                try? content.write(to: debugLogURL, atomically: true, encoding: .utf8)

            }
        }
    }

    func moveUpLastLogSeparatorInMemoryLog() {
        // In case there was no error during startTunnel, the log would still be in memory.
        // So we modify the in-memory log.
        let memoryLog = SwiftyBeaver.self.destinations.compactMap({ $0 as? MemoryDestination }).first
        if let memoryLog = memoryLog {
            let mirror = Mirror(reflecting: memoryLog)
            for child in mirror.children {
                // Read the private member called 'buffer' in the MemoryDestination instance
                if child.label == "buffer",
                   let buffer = child.value as? [String] {
                    var lines = buffer
                    if moveUpLastLogSeparator(in: &lines) {
                        memoryLog.start(with: lines)
                    }
                }
            }
        }
    }

    func indexOfTrailingAppLog(in lines: [String], logSeparatorIndex: Int, appSeparator: String, otherSeparators: [String]) -> Int? {
        for index in stride(from: logSeparatorIndex - 1, through: 0, by: -1) {
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

    func moveUpLastLogSeparator(in lines: inout [String]) -> Bool {
        // Move the last logSeparator line above the last "App:" line, so that the
        // app log goes together with the corresponding tunnel log.
        if let lastLogSeparatorIndex = lines.lastIndex(of: logSeparator),
            let appLogStartIndex = indexOfTrailingAppLog(in: lines, logSeparatorIndex: lastLogSeparatorIndex,
                                                            appSeparator: "App:", otherSeparators: ["Tunnel:", logSeparator]) {
            lines.replaceSubrange(lastLogSeparatorIndex ..< lastLogSeparatorIndex + 2, with: ["Tunnel:"])
            lines.insert(contentsOf: [logSeparator, ""], at: appLogStartIndex)
            return true
        }
        return false
    }
}
