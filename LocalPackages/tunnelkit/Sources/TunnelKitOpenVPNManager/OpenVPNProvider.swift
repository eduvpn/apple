//
//  OpenVPNProvider.swift
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
import TunnelKitManager
import TunnelKitOpenVPNCore

/// `VPNProvider` for OpenVPN protocol.
public class OpenVPNProvider: VPNProvider, VPNProviderIPC {
    private let provider: NetworkExtensionVPNProvider
    
    /**
     Initializes a provider with the bundle identifier of the `OpenVPNTunnelProvider`.
     
     - Parameter bundleIdentifier: The bundle identifier of the `OpenVPNTunnelProvider`.
     */
    public init(bundleIdentifier: String) {
        provider = NetworkExtensionVPNProvider(locator: NetworkExtensionTunnelLocator(bundleIdentifier: bundleIdentifier))
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
    
    // MARK: VPNProviderIPC
    
    public func requestDebugLog(fallback: (() -> String)?, completionHandler: @escaping (String) -> Void) {
        guard provider.status != .disconnected else {
            completionHandler(fallback?() ?? "")
            return
        }
        findAndRequestDebugLog { (recent) in
            DispatchQueue.main.async {
                guard let recent = recent else {
                    completionHandler(fallback?() ?? "")
                    return
                }
                completionHandler(recent)
            }
        }
    }

    public func requestBytesCount(completionHandler: @escaping ((UInt, UInt)?) -> Void) {
        provider.lookup { manager, error in
            guard let session = manager?.connection as? NETunnelProviderSession else {
                DispatchQueue.main.async {
                    completionHandler(nil)
                }
                return
            }
            do {
                try session.sendProviderMessage(Message.dataCount.data) { (data) in
                    guard let data = data, data.count == 16 else {
                        DispatchQueue.main.async {
                            completionHandler(nil)
                        }
                        return
                    }
                    let bytesIn: UInt = data.subdata(in: 0..<8).withUnsafeBytes { $0.load(as: UInt.self) }
                    let bytesOut: UInt = data.subdata(in: 8..<16).withUnsafeBytes { $0.load(as: UInt.self) }
                    DispatchQueue.main.async {
                        completionHandler((bytesIn, bytesOut))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completionHandler(nil)
                }
            }
        }
    }

    public func requestServerConfiguration(completionHandler: @escaping (Any?) -> Void) {
        provider.lookup { manager, error in
            guard let session = manager?.connection as? NETunnelProviderSession else {
                DispatchQueue.main.async {
                    completionHandler(nil)
                }
                return
            }
            do {
                try session.sendProviderMessage(Message.serverConfiguration.data) { (data) in
                    guard let data = data, let cfg = try? JSONDecoder().decode(OpenVPN.Configuration.self, from: data) else {
                        DispatchQueue.main.async {
                            completionHandler(nil)
                        }
                        return
                    }
                    DispatchQueue.main.async {
                        completionHandler(cfg)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completionHandler(nil)
                }
            }
        }
    }

    // MARK: Helpers

    private func findAndRequestDebugLog(completionHandler: @escaping (String?) -> Void) {
        provider.lookup { manager, error in
            guard let session = manager?.connection as? NETunnelProviderSession else {
                completionHandler(nil)
                return
            }
            OpenVPNProvider.requestDebugLog(session: session, completionHandler: completionHandler)
        }
    }

    private static func requestDebugLog(session: NETunnelProviderSession, completionHandler: @escaping (String?) -> Void) {
        do {
            try session.sendProviderMessage(Message.requestLog.data) { (data) in
                guard let data = data, !data.isEmpty else {
                    completionHandler(nil)
                    return
                }
                let newestLog = String(data: data, encoding: .utf8)
                completionHandler(newestLog)
            }
        } catch {
            completionHandler(nil)
        }
    }
}
