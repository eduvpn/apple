//
//  NetworkExtensionVPNProvider.swift
//  TunnelKit
//
//  Created by Davide De Rosa on 6/15/18.
//  Copyright (c) 2021 Davide De Rosa. All rights reserved.
//
//  https://github.com/passepartoutvpn
//
//  This file is part of TunnelKit.
//
//  TunnelKit is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  TunnelKit is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with TunnelKit.  If not, see <http://www.gnu.org/licenses/>.
//

import Foundation
import NetworkExtension
import SwiftyBeaver

private let log = SwiftyBeaver.self

/// `VPNProvider` based on the NetworkExtension framework.
public class NetworkExtensionVPNProvider: VPNProvider {
    private var manager: NEVPNManager?
    
    private let locator: NetworkExtensionLocator

    private var lastNotifiedStatus: VPNStatus?

    /**
     Initializes a provider with a `NetworkExtensionLocator`.
     
     - Parameter locator: A `NetworkExtensionLocator` able to locate a `NEVPNManager`.
     */
    public init(locator: NetworkExtensionLocator) {
        self.locator = locator

        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(vpnDidUpdate(_:)), name: .NEVPNStatusDidChange, object: nil)
        nc.addObserver(self, selector: #selector(vpnDidReinstall(_:)), name: .NEVPNConfigurationChange, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: VPNProvider

    public var isPrepared: Bool {
        return manager != nil
    }
    
    public var isEnabled: Bool {
        guard let manager = manager else {
            return false
        }
        return manager.isEnabled && manager.isOnDemandEnabled
    }
    
    public var status: VPNStatus {
        guard let neStatus = manager?.connection.status else {
            return .disconnected
        }
        switch neStatus {
        case .connected:
            return .connected
            
        case .connecting, .reasserting:
            return .connecting
            
        case .disconnecting:
            return .disconnecting
            
        case .disconnected, .invalid:
            return .disconnected

        @unknown default:
            return .disconnected
        }
    }
    
    public func prepare(completionHandler: (() -> Void)?) {
        locator.lookup { manager, error in
            self.manager = manager
            NotificationCenter.default.post(name: VPN.didPrepare, object: nil)
            completionHandler?()
        }
    }
    
    public func install(configuration: VPNConfiguration, completionHandler: ((Error?) -> Void)?) {
        guard let configuration = configuration as? NetworkExtensionVPNConfiguration else {
            fatalError("Not a NetworkExtensionVPNConfiguration")
        }
        locator.lookup { manager, error in
            guard let manager = manager else {
                completionHandler?(error)
                return
            }
            self.manager = manager
            manager.localizedDescription = configuration.title
            manager.protocolConfiguration = configuration.protocolConfiguration
            manager.onDemandRules = configuration.onDemandRules
            manager.isOnDemandEnabled = true
            manager.isEnabled = true
            manager.saveToPreferences { error in
                guard error == nil else {
                    manager.isOnDemandEnabled = false
                    manager.isEnabled = false
                    completionHandler?(error)
                    return
                }
                manager.loadFromPreferences { error in
                    completionHandler?(error)
                }
            }
        }
    }
    
    public func connect(completionHandler: ((Error?) -> Void)?) {
        do {
            try manager?.connection.startVPNTunnel()
            completionHandler?(nil)
        } catch let e {
            completionHandler?(e)
        }
    }
    
    public func disconnect(completionHandler: ((Error?) -> Void)?) {
        guard let manager = manager else {
            completionHandler?(nil)
            return
        }
        manager.connection.stopVPNTunnel()
        manager.isOnDemandEnabled = false
        manager.isEnabled = false
        manager.saveToPreferences(completionHandler: completionHandler)
    }
    
    public func reconnect(configuration: VPNConfiguration, delay: Double? = nil, completionHandler: ((Error?) -> Void)?) {
        guard let configuration = configuration as? NetworkExtensionVPNConfiguration else {
            fatalError("Not a NetworkExtensionVPNConfiguration")
        }
        let delay = delay ?? 2.0
        install(configuration: configuration) { error in
            guard error == nil else {
                completionHandler?(error)
                return
            }
            let connectBlock = {
                self.connect(completionHandler: completionHandler)
            }
            if self.status != .disconnected {
                self.manager?.connection.stopVPNTunnel()
                DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: connectBlock)
            } else {
                connectBlock()
            }
        }
    }
    
    public func uninstall(completionHandler: (() -> Void)?) {
        locator.lookup { manager, error in
            guard let manager = manager else {
                completionHandler?()
                return
            }
            manager.connection.stopVPNTunnel()
            manager.removeFromPreferences { error in
                self.manager = nil
                completionHandler?()
            }
        }
    }
    
    // MARK: Helpers
    
    public func lookup(completionHandler: @escaping (NEVPNManager?, Error?) -> Void) {
        locator.lookup(completionHandler: completionHandler)
    }

    // MARK: Notifications

    @objc private func vpnDidUpdate(_ notification: Notification) {
        guard let connection = notification.object as? NETunnelProviderSession else {
            return
        }
        log.debug("VPN status did change: \(connection.status.rawValue)")

        let status = self.status
        if let last = lastNotifiedStatus {
            guard status != last else {
                return
            }
        }
        lastNotifiedStatus = status

        NotificationCenter.default.post(name: VPN.didChangeStatus, object: self)
    }

    @objc private func vpnDidReinstall(_ notification: Notification) {
        NotificationCenter.default.post(name: VPN.didReinstall, object: self)
    }
}
