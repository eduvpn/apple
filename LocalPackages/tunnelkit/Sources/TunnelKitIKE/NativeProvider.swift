//
//  NativeProvider.swift
//  TunnelKit
//
//  Created by Davide De Rosa on 4/11/21.
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
import TunnelKitManager

/// `VPNProvider` for native IPSec/IKEv2 configurations.
public class NativeProvider: VPNProvider {
    private let provider: NetworkExtensionVPNProvider
    
    public init() {
        provider = NetworkExtensionVPNProvider(locator: NetworkExtensionNativeLocator())
    }
    
    // MARK: VPNProvider
    
    public var isPrepared: Bool {
        return provider.isPrepared
    }
    
    public var isEnabled: Bool {
        return provider.isEnabled
    }
    
    public var status: VPNStatus {
        return provider.status
    }
    
    public func prepare(completionHandler: (() -> Void)?) {
        provider.prepare(completionHandler: completionHandler)
    }
    
    public func install(configuration: VPNConfiguration, completionHandler: ((Error?) -> Void)?) {
        provider.install(configuration: configuration, completionHandler: completionHandler)
    }
    
    public func connect(completionHandler: ((Error?) -> Void)?) {
        provider.connect(completionHandler: completionHandler)
    }
    
    public func disconnect(completionHandler: ((Error?) -> Void)?) {
        provider.disconnect(completionHandler: completionHandler)
    }
    
    public func reconnect(configuration: VPNConfiguration, delay: Double? = nil, completionHandler: ((Error?) -> Void)?) {
        provider.reconnect(configuration: configuration, delay: delay, completionHandler: completionHandler)
    }
    
    public func uninstall(completionHandler: (() -> Void)?) {
        provider.uninstall(completionHandler: completionHandler)
    }
}
