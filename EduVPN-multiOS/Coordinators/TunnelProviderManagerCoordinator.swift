//
//  TunnelProviderManagerCoordinator.swift
//  eduVPN
//

import Foundation
import os.log
import NetworkExtension
import TunnelKit
import PromiseKit
import CoreData

enum TunnelProviderManagerCoordinatorError: Error {
    case missingDelegate
    case missingTunnelProviderManager
}

private let profileIdKey = "EduVPNprofileId"

protocol TunnelProviderManagerCoordinatorDelegate: class {
    
    func profileConfig(for profile: Profile) -> Promise<[String]>
    func updateProfileStatus(with status: NEVPNStatus)
}

class TunnelProviderManagerCoordinator: Coordinator {
    
    var childCoordinators: [Coordinator] = []
    weak var delegate: TunnelProviderManagerCoordinatorDelegate?
    var currentManager: NETunnelProviderManager?
    var viewContext: NSManagedObjectContext!
    
    func start() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(VPNStatusDidChange(notification:)),
                                               name: .NEVPNStatusDidChange,
                                               object: nil)
        #if os(iOS)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(refreshTunnelStatus),
                                               name: UIApplication.willEnterForegroundNotification,
                                               object: nil)
        #endif
    }

    var isActive: Bool {
        isStatusActive(currentManager?.connection.status ?? .invalid)
    }

    var appGroup: String {
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
    
    var vpnBundle: String {
        if let bundleID = Bundle.main.bundleIdentifier {
            return "\(bundleID).TunnelExtension"
        } else {
            fatalError("missing bundle ID")
        }
    }

    /// Delete the currently setup tunnel provider, if any
    func deleteConfiguration() -> Promise<Void> {
        return getCurrentTunnelProviderManager()
            .then { (manager: NETunnelProviderManager?) -> Promise<Void> in
                guard let manager = manager else {
                    return Promise.value(())
                }
                return manager.delete()
            }
    }

    /// Setup a tunnel provider (creating it if necessary) based on `profile`.
    /// If a previously setup tunnel is active, disconnect that before setting this up.
    func configure(profile: Profile) -> Promise<NETunnelProviderManager> {
        guard let delegate = delegate else {
            return Promise(error: TunnelProviderManagerCoordinatorError.missingDelegate)
        }

        #if targetEnvironment(simulator)
        print("SIMULATOR DOES NOT SUPPORT NETWORK EXTENSIONS")
        return Promise.value(NETunnelProviderManager())
        #else

        return getOrCreateTunnelProviderManager()
            .then { manager in
                // If a tunnel is active, request that it be disconnected
                manager.disconnect()
                    .map { _ in manager }
            }.then { manager in
                // Get the OpenVPN config for this profile
                delegate.profileConfig(for: profile)
                    .map { configLines in (manager, configLines) }
            }.then { (tuple: (NETunnelProviderManager, [String])) -> Promise<Void> in
                // Configure the tunnel provider
                let (manager, configLines) = tuple
                let profileUUID = getOrCreateProfileID(on: profile)
                let tunnelProviderProtocol = try getTunnelProviderProtocol(
                    vpnBundle: self.vpnBundle,
                    appGroup: self.appGroup,
                    configLines: configLines,
                    profileId: profileUUID.uuidString)
                return manager.saveTunnelProviderProtocol(tunnelProviderProtocol)
            }.then { [weak self] () -> Promise<NETunnelProviderManager> in
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

        #endif
    }

    /// Check whether the current tunnel provider, if any, has on-demand enabled.
    /// Currently used only from unused code.
    func checkOnDemandEnabled() -> Promise<Bool> {
        return getCurrentTunnelProviderManager()
            .map { $0?.isOnDemandEnabled ?? false }
    }

    /// Disconnect the currently setup tunnel provider, if any
    func disconnect() -> Promise<Void> {
        return getCurrentTunnelProviderManager()
            .then { (manager: NETunnelProviderManager?) -> Promise<Void> in
                guard let manager = manager else {
                    return Promise.value(())
                }
                return manager.disconnect()
            }
    }

    /// If currently connected, reconfigure with the profile from UserDefaults and reconnect
    func reconnect() -> Promise<Void> {
        return getCurrentTunnelProviderManager()
            .then { (manager: NETunnelProviderManager?) -> Promise<Void> in
                guard let manager = manager else {
                    return Promise.value(())
                }
                let status = manager.connection.status
                if status == .connected || status == .connecting || status == .reasserting {
                    if let configuredProfileId = UserDefaults.standard.configuredProfileId,
                        let configuredProfile = try Profile.findFirstInContext(self.viewContext, predicate: NSPredicate(format: "uuid == %@", configuredProfileId)) {
                        return self.configure(profile: configuredProfile)
                            .then { $0.connect() }
                    }
                }
                return Promise.value(())
            }
    }

    func getCurrentTunnelProviderManager() -> Promise<NETunnelProviderManager?> {
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

    func getOrCreateTunnelProviderManager() -> Promise<NETunnelProviderManager> {
        return getCurrentTunnelProviderManager().map { existingManager in
            let manager = existingManager ?? NETunnelProviderManager()
            self.currentManager = manager
            return manager
        }
    }
}

extension NETunnelProviderManager {
    func connect() -> Promise<Void> {
        return setOnDemand(enabled: true)
            .map { self.startTunnel() }
    }

    func disconnect() -> Promise<Void> {
        if isStatusActive(connection.status) {
            return setOnDemand(enabled: false)
                .map { self.stopTunnel() }
        } else {
            return Promise.value(())
        }
    }
}

// MARK: - NETunnelProviderManager core functions

private extension NETunnelProviderManager {
    var profileId: String {
        let protocolConfig = protocolConfiguration as? NETunnelProviderProtocol
        return (protocolConfig?.providerConfiguration?[profileIdKey] as? String) ?? ""
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

    func delete() -> Promise<Void> {
        return Promise { seal in
            removeFromPreferences { error in
                if let error = error {
                    os_log("error removing preferences: %{public}@",
                           log: Log.general, type: .error, error.localizedDescription)
                    seal.reject(error)
                    return
                }
                seal.fulfill(())
            }
        }
    }

    func startTunnel() {
        os_log("starting tunnel", log: Log.general, type: .info)
        if let session = tunnelSession() {
            do {
                try session.startTunnel()
            } catch let error {
                os_log("error starting tunnel: %{public}@",
                       log: Log.general, type: .error, error.localizedDescription)
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

    private func tunnelSession() -> NETunnelProviderSession? {
        guard let session = connection as? NETunnelProviderSession else {
            os_log("error getting tunnel session: %{public}@",
                   log: Log.general, type: .error,
                   "connection is not an NETunnelProviderSession")
            return nil
        }
        return session
    }
}

// MARK: - Updating connection status

extension TunnelProviderManagerCoordinator {
    /// Updates the delegate with the tunnel status.
    /// Called in iOS whenever the app is brought to the foreground.
    @objc private func refreshTunnelStatus() {
        firstly {
            getCurrentTunnelProviderManager()
        }.done { [weak self] manager in
            let status = manager?.connection.status ?? NEVPNStatus.invalid
            self?.delegate?.updateProfileStatus(with: status)
        }.catch { _ in
            // This catch block exists only to prevent a Swift warning
            os_log("error refreshing tunnel status",
                   log: Log.general, type: .error)
        }
    }

    @objc private func VPNStatusDidChange(notification: NSNotification) {
        guard let status = currentManager?.connection.status else {
            return
        }

        delegate?.updateProfileStatus(with: status)
    }
}

// MARK: - Log

extension TunnelProviderManagerCoordinator {
     func loadLog(completion: ((String) -> Void)? = nil) {
         guard let session = currentManager?.connection as? NETunnelProviderSession else {
             completion?("")
             return
         }

         switch session.status {
         case .connected, .reasserting:
             // Ask the tunnel process for the log
             try? session.sendProviderMessage(OpenVPNTunnelProvider.Message.requestLog.data) { data in
                 guard let data = data, let log = String(data: data, encoding: .utf8) else {
                     completion?("")
                     return
                 }
                 completion?(log)
             }
         case .disconnected:
             // Read the log file directly
             let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
             let tunnelKitDebugLogFilename = "debug.log"
             guard let debugLogURL = appGroupURL?.appendingPathComponent(tunnelKitDebugLogFilename) else {
                 completion?("")
                 return
             }
             completion?((try? String(contentsOf: debugLogURL)) ?? "")
         default:
             // When disconnecting, the tunnel process might be writing to the log.
             // When connecting, the log would contain only on the previous connection.
             completion?("")
         }
     }

     func canLoadLog() -> Bool {
         guard let session = currentManager?.connection as? NETunnelProviderSession else {
             return false
         }

         switch session.status {
         case .connected, .disconnected, .reasserting:
             return true
         default:
             return false
         }
     }
}

// MARK: - Private helpers

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
