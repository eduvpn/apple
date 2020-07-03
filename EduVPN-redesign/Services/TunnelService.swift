//
//  TunnelService.swift
//  eduVPN 2
//
//  Created by Johan Kool on 28/05/2020.
//

import Foundation
import os.log
import NetworkExtension
import TunnelKit
import PromiseKit

// TEMP
struct Profile {
    let id: String
}

protocol TunnelServiceType {
    func setConnectionEnabled(_ enabled: Bool, server: AnyObject, profile: Profile) -> Promise<Void>
    func relogin(server: AnyObject)
}

class TunnelService: TunnelServiceType {
    
//    let settings: SettingsServiceType
//
//    init(settings: SettingsServiceType) {
//        self.settings = settings
//    }
    
    func setConnectionEnabled(_ enabled: Bool, server: AnyObject, profile: Profile) -> Promise<Void> {
        return getOrCreateTunnelProviderManager()
            .then { manager in
                // If a tunnel is active, request that it be disconnected
                manager.disconnect()
                    .map { _ in manager }
            }
            .then { manager in
                // Get the OpenVPN config for this profile
//                delegate.profileConfig(for: profile)
//                    .map { configLines in (manager, configLines) }
            }
            .then { (tuple: (NETunnelProviderManager, [String])) -> Promise<Void> in
                // Configure the tunnel provider
                let (manager, configLines) = tuple
                let profileUUID = getOrCreateProfileID(on: profile)
                let tunnelProviderProtocol = try getTunnelProviderProtocol(
                    vpnBundle: self.vpnBundle,
                    appGroup: self.appGroup,
                    configLines: configLines,
                    profileId: profileUUID.uuidString)
                return manager.saveTunnelProviderProtocol(tunnelProviderProtocol)
            }
            .then { [weak self] () -> Promise<NETunnelProviderManager> in
                // Reload tunnel configuration
                guard let self = self else {
                    throw TunnelProviderManagerCoordinatorError.missingTunnelProviderManager
                }
                return self.getCurrentTunnelProviderManager().map { manager in
                    guard let manager = manager else {
                        throw TunnelProviderManagerCoordinatorError.missingTunnelProviderManager
                    }
                    return manager
                }
            }
    }
    
    func relogin(server: AnyObject) {
        
    }
    
    private var currentManager: NETunnelProviderManager?
    
    private var vpnBundle: String {
        if let bundleID = Bundle.main.bundleIdentifier {
            return "\(bundleID).TunnelExtension"
        } else {
            fatalError("missing bundle ID")
        }
    }
    
    private func getCurrentTunnelProviderManager() -> Promise<NETunnelProviderManager?> {
        return Promise { seal in
            NETunnelProviderManager.loadAllFromPreferences { (managers, error) in
                if let error = error {
                    os_log("error loading preferences: %{public}@",
                           log: Log.general, type: .error, error.localizedDescription)
                    seal.reject(error)
                    return
                }
                
                let manager = (managers ?? []).first(where: { manager in
                    let prot = (manager.protocolConfiguration as? NETunnelProviderProtocol)
                    return (prot?.providerBundleIdentifier == self.vpnBundle)
                })
                
                self.currentManager = manager
                seal.fulfill(manager)
            }
        }
    }
    
    private func getOrCreateTunnelProviderManager() -> Promise<NETunnelProviderManager> {
        return getCurrentTunnelProviderManager().map { existingManager in
            let manager = existingManager ?? NETunnelProviderManager()
            self.currentManager = manager
            return manager
        }
    }
}

fileprivate extension NETunnelProviderManager {
    func connect() -> Promise<Void> {
        return setOnDemand(enabled: true)
            .map { try self.startTunnel() }
    }
    
    func disconnect() -> Promise<Void> {
        if protocolConfiguration != nil {
            return setOnDemand(enabled: false)
                .map { self.stopTunnel() }
        } else {
            return Promise.value(())
        }
    }
    
    func tunnelSession() -> NETunnelProviderSession? {
        guard let session = connection as? NETunnelProviderSession else {
            os_log("error getting tunnel session: %{public}@",
                   log: Log.general, type: .error,
                   "connection is not an NETunnelProviderSession")
            return nil
        }
        return session
    }
    
    func startTunnel() throws {
        os_log("starting tunnel", log: Log.general, type: .info)
        if let session = tunnelSession() {
            do {
                try session.startTunnel()
            } catch let error {
                os_log("error starting tunnel: %{public}@",
                       log: Log.general, type: .error, error.localizedDescription)
                throw error
            }
        }
    }
    
    func stopTunnel() {
        os_log("stopping tunnel", log: Log.general, type: .info)
        if let session = tunnelSession(), isStatusActive(session.status) {
            session.stopTunnel()
        }
    }
    
    func setOnDemand(enabled: Bool) -> Promise<Void> {
        isOnDemandEnabled = enabled
        if enabled {
            let rule = NEOnDemandRuleConnect()
            rule.interfaceTypeMatch = .any
            onDemandRules = [rule]
        }
        return saveModifications()
    }
    
    func saveModifications() -> Promise<Void> {
        #if targetEnvironment(simulator)
        print("SIMULATOR DOES NOT SUPPORT NETWORK EXTENSIONS")
        return Promise.value(())
        #else
        
        return Promise { seal in
            saveToPreferences { error in
                if let error = error {
                    os_log("error saving preferences: %{public}@",
                           log: Log.general, type: .error, error.localizedDescription)
                    seal.reject(error)
                    return
                }
                seal.fulfill(())
            }
        }
        
        #endif
    }
}

private func isStatusActive(_ status: NEVPNStatus) -> Bool {
    switch status {
    case .connected, .connecting, .disconnecting, .reasserting:
        return true
    case .invalid, .disconnected:
        return false
    @unknown default:
        return false
    }
}
