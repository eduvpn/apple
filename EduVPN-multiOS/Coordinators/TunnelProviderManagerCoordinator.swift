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
                                               selector: #selector(refresh),
                                               name: UIApplication.willEnterForegroundNotification,
                                               object: nil)
        #endif
    }
    
    var isActive: Bool {
        let status = currentManager?.connection.status ?? .invalid
        switch status {
        case .connected, .connecting, .disconnecting, .reasserting:
            return true
        case .invalid, .disconnected:
            return false
        @unknown default:
            return false
        }
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

    func deleteConfiguration() -> Promise<Void> {
        return Promise(resolver: { (resolver) in
            reloadCurrentManager { (error) in
                if let error = error {
                    os_log("error reloading preferences: %{public}@", log: Log.general, type: .error, error.localizedDescription)
                    resolver.reject(error)
                    return
                }

                guard let manager = self.currentManager else {
                    resolver.reject(TunnelProviderManagerCoordinatorError.missingTunnelProviderManager)
                    return
                }

                manager.removeFromPreferences(completionHandler: { (error) in
                    if let error = error {
                        os_log("error removing preferences: %{public}@", log: Log.general, type: .error, error.localizedDescription)
                        resolver.reject(error)
                        return
                    }
                })
                resolver.fulfill(())
            }
        })
    }
    
    func configure(profile: Profile) -> Promise<Void> {
        guard let delegate = delegate else {
            return Promise(error: TunnelProviderManagerCoordinatorError.missingDelegate)
        }
        
        return delegate.profileConfig(for: profile).then({ (configLines) -> Promise<Void> in

            #if targetEnvironment(simulator)
            
            print("SIMULATOR DOES NOT SUPPORT NETWORK EXTENSIONS")
            return Promise.value(())
            
            #else

            let parseResult = try! OpenVPN.ConfigurationParser.parsed(fromLines: configLines) //swiftlint:disable:this force_try

            return Promise(resolver: { resolver in
                var configBuilder = parseResult.configuration.builder()
                configBuilder.tlsSecurityLevel = UserDefaults.standard.tlsSecurityLevel.rawValue
                
                self.configureVPN({ _ in
                    var builder = OpenVPNTunnelProvider.ConfigurationBuilder(sessionConfiguration: configBuilder.build())
                    builder.masksPrivateData = false
                    builder.shouldDebug = true

                    #if DEBUG
                    #else
                    builder.debugLogFormat = "$HH:mm:ss$d $L - $M"
                    #endif

                    let configuration = builder.build()
                    
                    os_log("App group: %{public}@", log: Log.general, type: .info, self.appGroup)

                    let tunnelProviderProtocolConfiguration = try! configuration.generatedTunnelProtocol( //swiftlint:disable:this force_try
                        withBundleIdentifier: self.vpnBundle,
                        appGroup: self.appGroup)
                    
                    let uuid: UUID
                    if let profileId = profile.uuid {
                        uuid = profileId
                    } else {
                        uuid = UUID()
                        profile.uuid = uuid
                        profile.managedObjectContext?.saveContext()
                    }
                    
                    tunnelProviderProtocolConfiguration.providerConfiguration?[profileIdKey] = uuid.uuidString
                    
                    return tunnelProviderProtocolConfiguration
                }, completionHandler: { error in
                    if let error = error {
                        os_log("configure error: %{public}@", log: Log.general, type: .error, error.localizedDescription)
                    }
                    resolver.resolve(error)
                })
            })
            
            #endif
        })
    }
    
    func connect() -> Promise<Void> {
        os_log("starting tunnel", log: Log.general, type: .info)
        #if targetEnvironment(simulator)
        
        print("SIMULATOR DOES NOT SUPPORT NETWORK EXTENSIONS")
        return Promise.value(())
        
        #else
        
        return Promise(resolver: { resolver in
            guard let currentManager = self.currentManager, let session = currentManager.connection as? NETunnelProviderSession else {
                let error = TunnelProviderManagerCoordinatorError.missingTunnelProviderManager
                os_log("error connecting tunnel: %{public}@", log: Log.general, type: .error, error.localizedDescription)
                resolver.reject(error)
                return
            }
            
            // Always enable "on demand"
            currentManager.isOnDemandEnabled = true
            let rule = NEOnDemandRuleConnect()
            rule.interfaceTypeMatch = .any
            currentManager.onDemandRules = [rule]
            
            currentManager.saveToPreferences(completionHandler: { error in
                if let error = error {
                    os_log("error saveToPreferences tunnel: %{public}@", log: Log.general, type: .error, error.localizedDescription)
                    resolver.reject(error)
                    return
                }
                
                do {
                    try session.startTunnel()
                    resolver.resolve(Result.fulfilled(()))
                } catch let error {
                    os_log("error starting tunnel: %{public}@", log: Log.general, type: .error, error.localizedDescription)
                    resolver.reject(error)
                }
            })
        })
        
        #endif
    }

    func checkOnDemandEnabled() -> Promise<Bool> {
        return Promise(resolver: { resolver in
            reloadCurrentManager { _ in
                resolver.fulfill(self.currentManager?.isOnDemandEnabled ?? false)
            }
        })
    }
    
    func disconnect() -> Promise<Void> {
        os_log("stopping tunnel", log: Log.general, type: .info)
        #if targetEnvironment(simulator)
        
        print("SIMULATOR DOES NOT SUPPORT NETWORK EXTENSIONS")
        return Promise.value(())
        
        #else
        
        return Promise(resolver: { resolver in
            configureVPN({ _ in
                self.currentManager?.isOnDemandEnabled = false
                return nil
            }, completionHandler: { error in
                self.currentManager?.connection.stopVPNTunnel()
                resolver.resolve(error)
            })
        })
        
        #endif
    }
    
    func reconnect() -> Promise<Void> {
        return firstly { () -> Promise<Void> in
            let session = self.currentManager?.connection as? NETunnelProviderSession
            switch session?.status ?? .invalid {
                
            case .connected, .connecting, .reasserting:
                if let configuredProfileId = UserDefaults.standard.configuredProfileId, let configuredProfile = try Profile.findFirstInContext(viewContext, predicate: NSPredicate(format: "uuid == %@", configuredProfileId)) {
                    return self.configure(profile: configuredProfile).then {
                        return self.connect()
                    }
                } else {
                    return Promise.value(())
                }
                
            default:
                return Promise.value(())
                
            }
        }
    }

    func configureVPN(_ configure: @escaping (NETunnelProviderManager) -> NETunnelProviderProtocol?,
                      completionHandler: @escaping (Error?) -> Void) {
        
        reloadCurrentManager { error in
            if let error = error {
                os_log("error reloading preferences: %{public}@",
                       log: Log.general,
                       type: .error,
                       error.localizedDescription)
                
                completionHandler(error)
                return
            }
            
            guard let manager = self.currentManager else {
                completionHandler(TunnelProviderManagerCoordinatorError.missingTunnelProviderManager)
                return
            }

            if let protocolConfiguration = configure(manager) {
                manager.protocolConfiguration = protocolConfiguration
            }
            manager.isEnabled = true
            manager.onDemandRules = [NEOnDemandRuleConnect()]
            
            manager.saveToPreferences { error in
                if let error = error {
                    os_log("error saving preferences: %{public}@", log: Log.general, type: .error, error.localizedDescription)
                    completionHandler(error)
                    return
                }
                
                if let protocolConfiguration = manager.protocolConfiguration as? NETunnelProviderProtocol {
                    UserDefaults.standard.configuredProfileId = (protocolConfiguration.providerConfiguration?[profileIdKey] as? String)
                }
                
                os_log("saved preferences", log: Log.general, type: .info)
                self.reloadCurrentManager(completionHandler)
            }
        }
    }
    
    func reloadCurrentManager(_ completionHandler: ((Error?) -> Void)?) {
        NETunnelProviderManager.loadAllFromPreferences { (managers, error) in
            if let error = error {
                completionHandler?(error)
                return
            }
            
            var manager: NETunnelProviderManager?
            for man in managers ?? [] {
                if let prot = man.protocolConfiguration as? NETunnelProviderProtocol {
                    if prot.providerBundleIdentifier == self.vpnBundle {
                        //    os_log("provider config: \(prot.providerConfiguration)", log: Log.general, type: .info)
                        manager = man
                        break
                    }
                }
            }
            
            if manager == nil {
                manager = NETunnelProviderManager()
            }
            
            self.currentManager = manager
            completionHandler?(nil)
        }
    }
    
    @objc private func refresh() {
        reloadCurrentManager { [weak self] _ in
            guard let self = self else { return }

            if let prot = self.currentManager?.protocolConfiguration as? NETunnelProviderProtocol {
                if prot.providerBundleIdentifier == self.vpnBundle {
                    let status = self.currentManager?.connection.status ?? NEVPNStatus.invalid
                    self.delegate?.updateProfileStatus(with: status)
                }
            }
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
