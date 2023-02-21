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
        self.configuration = configuration.badAllowedIPsRemoved(logger: logger)
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

private extension TunnelConfiguration {

    // badAllowedIPsRemoved():
    // When an IPv4 address in AllowedIPs overlaps with 0.0.0.0/8, the tunnel doesn't work.
    // Not sure why. As a workaround, we replace those IPs such that there's no such overlap.
    // It's anyway not valid to have a source / destination address in 0.0.0.0/8, so we
    // exclude that range.
    // For example, "0.0.0.0/6" shall be replaced with ["2.0.0.0/7", "1.0.0.0/8"].

    func badAllowedIPsRemoved(logger: Logger) -> TunnelConfiguration {
        guard hasBadAllowedIPs() else {
            return self
        }

        let replacementIPv4AddressRanges = [
            IPAddressRange(from: "64.0.0.0/2"), // 01XXXXXX.X.X.X
            IPAddressRange(from: "32.0.0.0/3"), // 001XXXXX.X.X.X
            IPAddressRange(from: "16.0.0.0/4"), // 0001XXXX.X.X.X
            IPAddressRange(from: "8.0.0.0/5"),  // 00001XXX.X.X.X
            IPAddressRange(from: "4.0.0.0/6"),  // 000001XX.X.X.X
            IPAddressRange(from: "2.0.0.0/7"),  // 0000001X.X.X.X
            IPAddressRange(from: "1.0.0.0/8")   // 00000001.X.X.X
        ]

        let peers: [PeerConfiguration] = self.peers.map { originalPeer in
            var allowedIPs: [IPAddressRange] = []
            for ipAddressRange in originalPeer.allowedIPs {
                if let ipv4Address = ipAddressRange.address as? IPv4Address {
                    if ipv4Address == Self.allZeroIPv4Address &&
                        ipAddressRange.networkPrefixLength > 0 {

                        if ipAddressRange.networkPrefixLength < 8 {
                            let index = Int(ipAddressRange.networkPrefixLength - 1)
                            replacementIPv4AddressRanges[index...].forEach { replacementAddressRange in
                                if let replacementAddressRange = replacementAddressRange {
                                    allowedIPs.append(replacementAddressRange)
                                }
                            }
                        } else {
                            // We ignore IPv4 ranges that are 0.0.0.0/N, where N >= 8
                            // because they cannot be valid source or destination addresses
                        }

                    } else {
                        allowedIPs.append(ipAddressRange)
                    }
                } else {
                    allowedIPs.append(ipAddressRange)
                }
            }

            logger.log("Original AllowedIPs was: \(originalPeer.allowedIPs.map { $0.stringRepresentation }.joined(separator: ", "))")
            logger.log("Rewriting AllowedIPs as: \(allowedIPs.map { $0.stringRepresentation }.joined(separator: ", "))")

            var peer = PeerConfiguration(publicKey: originalPeer.publicKey)
            peer.preSharedKey = originalPeer.preSharedKey
            peer.allowedIPs = allowedIPs
            peer.endpoint = originalPeer.endpoint
            peer.persistentKeepAlive = originalPeer.persistentKeepAlive
            return peer
        }

        return TunnelConfiguration(name: self.name, interface: self.interface, peers: peers)
    }

    static let allZeroIPv4Address = IPv4Address("0.0.0.0")

    func hasBadAllowedIPs() -> Bool {
        for peer in peers {
            for ipAddressRange in peer.allowedIPs {
                if let ipv4Address = ipAddressRange.address as? IPv4Address {
                    if ipv4Address == Self.allZeroIPv4Address &&
                        ipAddressRange.networkPrefixLength > 0 {
                        return true
                    }
                }
            }
        }
        return false
    }
}
