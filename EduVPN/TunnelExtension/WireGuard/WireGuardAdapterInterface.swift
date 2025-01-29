//
//  WireGuardAdapterInterface.swift
//  TunnelExtension
//
//  Copyright © 2020-2023 The Commons Conservancy. All rights reserved.
//

import NetworkExtension
import WireGuardKit

class WireGuardAdapterInterface: TunnelAdapterInterface {
    private var configuration: WireGuardKit.TunnelConfiguration
    private var logger: Logger

    private var adapter: WireGuardAdapter?

    convenience init?(wgQuickConfig: String, logger: Logger) {
        guard let tunnelConfiguration = try? TunnelConfiguration(fromWgQuickConfig: wgQuickConfig) else {
            logger.log("Unable to parse wg-quick config")
            return nil
        }
        self.init(configuration: tunnelConfiguration, logger: logger)
    }

    init(configuration: WireGuardKit.TunnelConfiguration, logger: Logger) {
        self.configuration = configuration
        self.logger = logger
    }

    func start(packetTunnelProvider: NEPacketTunnelProvider, options: StartTunnelOptions, completionHandler: @escaping (Error?) -> Void) {
        logger.log("Starting WireGuard tunnel")
        let adapter = WireGuardAdapter(with: packetTunnelProvider) { [weak self] _, message in
            self?.logger.log(message)
        }
        adapter.start(tunnelConfiguration: configuration) { [weak self] adapterError in
            if adapterError == nil {
                let interfaceName = self?.adapter?.interfaceName ?? "unknown"
                self?.logger.log("Tunnel interface is \(interfaceName)")
            }
            completionHandler(adapterError)
        }
        self.adapter = adapter
    }

    func stop(completionHandler: @escaping (Error?) -> Void) {
        adapter?.stop(completionHandler: completionHandler)
    }

    func wake() {
        // Nothing to do
    }

    func sleep(completionHandler: @escaping () -> Void) {
        // Mothing to do
    }

    func getTransferredByteCount(completionHandler: @escaping (TransferredByteCount?) -> Void) {
        adapter?.getRuntimeConfiguration { settings in
            guard let settings = settings,
                  let runtimeConfig = try? TunnelConfiguration(fromUapiConfig: settings, basedOn: self.configuration) else {
                completionHandler(nil)
                return
            }
            let rxBytesTotal = runtimeConfig.peers.reduce(0) { $0 + ($1.rxBytes ?? 0) }
            let txBytesTotal = runtimeConfig.peers.reduce(0) { $0 + ($1.txBytes ?? 0) }
            let transferredByteCount = TransferredByteCount(inbound: rxBytesTotal, outbound: txBytesTotal)
            completionHandler(transferredByteCount)
        }
    }

    func networkAddresses() -> [String]? {
        return configuration.interface.addresses.map { "\($0.address)" }
    }
}
