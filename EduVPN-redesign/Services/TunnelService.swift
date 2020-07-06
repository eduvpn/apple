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

protocol TunnelServiceType {
    func setConnectionEnabled(_ enabled: Bool, server: AnyObject, profile: Profile) -> Promise<Void>
    func relogin(server: AnyObject)
}

enum TunnelServiceError: Error {
    case missingTunnelProviderManager
}

class TunnelService: TunnelServiceType {
    
    let serverApiService: ServerApiServiceType

    init(serverApiService: ServerApiServiceType) {
        self.serverApiService = serverApiService
    }
    
    func setConnectionEnabled(_ enabled: Bool, server: AnyObject, profile: Profile) -> Promise<Void> {
        if enabled {
            return getOrCreateTunnelProviderManager()
                .then { manager in
                    // If a tunnel is active, request that it be disconnected
                    manager.disconnect()
                        .map { _ in manager }
                }
                .then { manager in
                    // Get the OpenVPN config for this profile
                    self.serverApiService.profileConfig(for: profile)
                        .map { configLines in (manager, configLines) }
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
                        throw TunnelServiceError.missingTunnelProviderManager
                    }
                    return self.getCurrentTunnelProviderManager().map { manager in
                        guard let manager = manager else {
                            throw TunnelServiceError.missingTunnelProviderManager
                        }
                        return manager
                    }
                }.then {
                    $0.connect()
                }
        } else {
            return getCurrentTunnelProviderManager()
                .then { manager -> Promise<Void>  in
                    guard let manager = manager else {
                        throw TunnelServiceError.missingTunnelProviderManager
                    }
                    return manager.disconnect()
                        .map { _ in Void() }
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
    
    private var appGroup: String {
        if let bundleID = Bundle.main.bundleIdentifier {
            #if os(macOS)
            let prefix = (Bundle.main.infoDictionary?["AppIdentifierPrefix"] as? String) ?? ""
            #else
            let prefix = ""
            #endif
            return "\(prefix)group.\(bundleID)"
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
    
    private func tunnelSession() -> NETunnelProviderSession? {
        guard let session = connection as? NETunnelProviderSession else {
            os_log("error getting tunnel session: %{public}@",
                   log: Log.general, type: .error,
                   "connection is not an NETunnelProviderSession")
            return nil
        }
        return session
    }
    
    private func startTunnel() throws {
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
    
    private func stopTunnel() {
        os_log("stopping tunnel", log: Log.general, type: .info)
        if let session = tunnelSession(), session.status.isActive {
            session.stopTunnel()
        }
    }
    
    private func setOnDemand(enabled: Bool) -> Promise<Void> {
        isOnDemandEnabled = enabled
        if enabled {
            let rule = NEOnDemandRuleConnect()
            rule.interfaceTypeMatch = .any
            onDemandRules = [rule]
        }
        return saveModifications()
    }
    
    private func saveModifications() -> Promise<Void> {
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
    
    func saveTunnelProviderProtocol(_ tunnelProviderProtocol: NETunnelProviderProtocol) -> Promise<Void> {
          protocolConfiguration = tunnelProviderProtocol
          isEnabled = true
          isOnDemandEnabled = false
          onDemandRules = [NEOnDemandRuleConnect()]

          return saveModifications()
              .map { _ in
                  if let protocolConfiguration = self.protocolConfiguration as? NETunnelProviderProtocol {
                      UserDefaults.standard.configuredProfileId =
                          (protocolConfiguration.providerConfiguration?[profileIdKey] as? String)
                  }
              }
      }
}

// MARK: - Private helpers

fileprivate extension NEVPNStatus {
    var isActive: Bool {
        switch self {
        case .connected, .connecting, .disconnecting, .reasserting:
            return true
        case .invalid, .disconnected:
            return false
        @unknown default:
            return false
        }
    }
}

/// If `profile` already has an uuid, return it
/// Else, set a uuid on `profile` and return it.
private func getOrCreateProfileID(on profile: Profile) -> UUID {
    if let existingUUID = profile.uuid {
        return existingUUID
    } else {
        let newUUID = UUID()
        profile.uuid = newUUID
        profile.managedObjectContext?.saveContext()
        return newUUID
    }
}

/// Create an NETunnelProviderProtocol from the contents of an OpenVPN config file
private func getTunnelProviderProtocol(vpnBundle: String, appGroup: String,
                                       configLines: [String], profileId: String) throws
    -> NETunnelProviderProtocol {
    let parseResult = try OpenVPN.ConfigurationParser.parsed(fromLines: configLines)

    var configBuilder = parseResult.configuration.builder()
    configBuilder.tlsSecurityLevel = UserDefaults.standard.tlsSecurityLevel.rawValue

    var providerConfigBuilder = OpenVPNTunnelProvider.ConfigurationBuilder(sessionConfiguration: configBuilder.build())
    providerConfigBuilder.masksPrivateData = false
    providerConfigBuilder.shouldDebug = true

    let providerConfig = providerConfigBuilder.build()
    let tunnelProviderProtocolConfig = try providerConfig.generatedTunnelProtocol(
        withBundleIdentifier: vpnBundle,
        appGroup: appGroup)
    tunnelProviderProtocolConfig.providerConfiguration?[profileIdKey] = profileId

    return tunnelProviderProtocolConfig
}

private let profileIdKey = "EduVPNprofileId"
