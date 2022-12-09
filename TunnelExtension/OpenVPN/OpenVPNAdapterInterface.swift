//
//  OpenVPNAdapterInterface.swift
//  TunnelExtension
//
//  Copyright © 2020-2023 The Commons Conservancy. All rights reserved.
//

import NetworkExtension
import TunnelKitOpenVPNAppExtension
import TunnelKitOpenVPNManager
import TunnelKitOpenVPNCore
import TunnelKitAppExtension
import TunnelKitManager
import TunnelKitCore
import SwiftyBeaver

class OpenVPNAdapterInterface: TunnelAdapterInterface {

    class LoggerDestination: BaseDestination {
        private let logger: Logger

        init(logger: Logger) {
            self.logger = logger
            super.init()
        }

        override open func send(_ level: SwiftyBeaver.Level, msg: String, thread: String,
                                file: String, function: String, line: Int, context: Any? = nil) -> String? {
            if let formattedString = super.send(level, msg: msg, thread: thread, file: file, function: function, line: line, context: context) {
                logger.log(formattedString)
                return formattedString
            }
            return nil
        }
    }

    private var configuration: OpenVPN.ProviderConfiguration
    private var credentials: OpenVPN.Credentials?
    private var logger: Logger

    private var adapter: OpenVPNAdapter?

    convenience init?(tunnelKitConfigJson: Data, credentials: OpenVPN.Credentials?, logger: Logger) {
        guard let providerConfig = try? JSONDecoder().decode(OpenVPN.ProviderConfiguration.self, from: tunnelKitConfigJson) else {
            return nil
        }
        self.init(configuration: providerConfig, credentials: credentials, logger: logger)
    }

    init(configuration: OpenVPN.ProviderConfiguration, credentials: OpenVPN.Credentials?, logger: Logger) {
        self.configuration = configuration
        self.credentials = credentials
        self.logger = logger
    }

    func start(packetTunnelProvider: NEPacketTunnelProvider, options: StartTunnelOptions, completionHandler: @escaping (Error?) -> Void) {
        logger.log("Starting OpenVPN tunnel")

        let loggerDestination = LoggerDestination(logger: logger)
        loggerDestination.minLevel = .debug
        loggerDestination.format = "$Dyyyy-MM-dd HH:mm:ss.SSS$d $L $N.$F:$l - $M"
        SwiftyBeaver.addDestination(loggerDestination)
        CoreConfiguration.masksPrivateData = self.configuration.masksPrivateData

        let adapter = OpenVPNAdapter(with: packetTunnelProvider)

        adapter.flushLogHandler = { [weak self] in self?.logger.flushToDisk() }

        if !options.isStartedByApp {
            adapter.authFailShutdownHandler = { [weak packetTunnelProvider] in
                // Using deprecated call because there's no alternative
                packetTunnelProvider?.displayMessage(
                    """
                    VPN authentication failed. You can re-authenticate your VPN
                    connection in the app by turning it off, and then back on.
                    """,
                    completionHandler: { _ in })
            }
        }

        adapter.start(
            providerConfiguration: self.configuration,
            credentials: self.credentials, completionHandler: completionHandler)
        self.adapter = adapter
    }

    func stop(completionHandler: @escaping (Error?) -> Void) {
        adapter?.stop {
            completionHandler(nil)
        }
    }

    func wake() {
#if os(iOS)
        // Nothing to do
#else
        adapter?.resume()
#endif
    }

    func sleep(completionHandler: @escaping () -> Void) {
#if os(iOS)
        // Nothing to do
        completionHandler()
#else
        adapter?.pause(completionHandler: completionHandler)
#endif
    }

    func getTransferredByteCount(completionHandler: @escaping (TransferredByteCount?) -> Void) {
        guard let dataCount = adapter?.dataCount() else {
            return completionHandler(nil)
        }
        let transferredByteCount = TransferredByteCount(
            inbound: UInt64(dataCount.received),
            outbound: UInt64(dataCount.sent))
        completionHandler(transferredByteCount)
    }

    func networkAddresses() -> [String]? {
        guard let serverConfiguration = adapter?.serverConfiguration() else {
            return nil
        }
        var addresses: [String] = []
        if let ipv4Address = serverConfiguration.ipv4?.address {
            addresses.append(ipv4Address)
        }
        if let ipv6Address = serverConfiguration.ipv6?.address {
            addresses.append(ipv6Address)
        }
        return addresses
    }

}
