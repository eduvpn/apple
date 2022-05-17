//
//  NetworkExtensionLocator.swift
//  TunnelKit
//
//  Created by Davide De Rosa on 8/25/21.
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

/// Entity able to look up a `NEVPNManager`.
public protocol NetworkExtensionLocator {

    /**
     Looks up the VPN manager.
     
     - Parameter completionHandler: The completion handler with a `NEVPNManager` or an error (if not found).
     */
    func lookup(completionHandler: @escaping (NEVPNManager?, Error?) -> Void)
}

/// Locator for native VPN protocols.
public class NetworkExtensionNativeLocator: NetworkExtensionLocator {

    public init() {
    }

    // MARK: NetworkExtensionLocator

    public func lookup(completionHandler: @escaping (NEVPNManager?, Error?) -> Void) {
        let manager = NEVPNManager.shared()
        manager.loadFromPreferences { (error) in
            guard error == nil else {
                completionHandler(nil, error)
                return
            }
            completionHandler(manager, nil)
        }
    }
}

/// Locator for tunnel VPN protocols.
public class NetworkExtensionTunnelLocator: NetworkExtensionLocator {
    private let bundleIdentifier: String
    
    /**
     Initializes the locator with the bundle identifier of the tunnel provider.
     
     - Parameter bundleIdentifier: The bundle identifier of the tunnel provider.
     */
    public init(bundleIdentifier: String) {
        self.bundleIdentifier = bundleIdentifier
    }
    
    // MARK: NetworkExtensionLocator
    
    public func lookup(completionHandler: @escaping (NEVPNManager?, Error?) -> Void) {
        NETunnelProviderManager.loadAllFromPreferences { (managers, error) in
            guard error == nil else {
                completionHandler(nil, error)
                return
            }
            let manager = managers?.first {
                guard let ptm = $0.protocolConfiguration as? NETunnelProviderProtocol else {
                    return false
                }
                return (ptm.providerBundleIdentifier == self.bundleIdentifier)
            }
            completionHandler(manager ?? NETunnelProviderManager(), nil)
        }
    }
}
