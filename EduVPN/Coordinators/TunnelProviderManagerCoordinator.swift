//
//  TunnelProviderManagerCoordinator.swift
//  EduVPN
//
//  Created by Jeroen Leenarts on 13/12/2018.
//  Copyright © 2018 SURFNet. All rights reserved.
//

import Foundation
import os.log
import NetworkExtension
import TunnelKit
import PromiseKit

enum TunnelProviderManagerCoordinatorError: Error {
    case missingDelegate
}

private let profileIdKey = "EduVPNprofileId"

protocol TunnelProviderManagerCoordinatorDelegate: class {
    func profileConfig(for profile: Profile) -> Promise<URL>
}

class TunnelProviderManagerCoordinator: Coordinator {
    var childCoordinators: [Coordinator] = []
    weak var delegate: TunnelProviderManagerCoordinatorDelegate?
    var currentManager: NETunnelProviderManager?

    func start() {
    }
    
    var appGroup: String {
        if let bundleID = Bundle.main.bundleIdentifier {
            return "group.\(bundleID)"
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

    
    var configuredProfileUuid: String?  {
        return UserDefaults.standard.configuredProfileId
    }
    
    func configure(profile: Profile)  -> Promise<Void> {
        guard let delegate = delegate else {
            return Promise(error: TunnelProviderManagerCoordinatorError.missingDelegate)
        }
        return delegate.profileConfig(for: profile).then({ (configUrl) -> Promise<Void> in
            let parseResult = try! ConfigurationParser.parsed(fromURL: configUrl) //swiftlint:disable:this force_try
            
            return Promise(resolver: { (resolver) in
                self.configureVPN({ (_) in
                    let sessionConfig = parseResult.configuration.builder().build()
                    var builder = TunnelKitProvider.ConfigurationBuilder(sessionConfiguration: sessionConfig)
                    builder.endpointProtocols = parseResult.protocols
                    let configuration = builder.build()
                    
                    let tunnelProviderProtocolConfiguration = try! configuration.generatedTunnelProtocol( //swiftlint:disable:this force_try
                        withBundleIdentifier: self.vpnBundle,
                        appGroup: self.appGroup,
                        hostname: parseResult.hostname)
                    
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
                }, completionHandler: { (error) in
                    if let error = error {
                        os_log("configure error: %{public}@", log: Log.general, type: .error, error.localizedDescription)
                        resolver.reject(error)
                        return
                    }
                    resolver.resolve(Result.fulfilled(()))
                })
            })
        })
    }
    
    func connect(profile: Profile) -> Promise<Void> {
        return Promise(resolver: { (resolver) in
            let session = self.currentManager?.connection as! NETunnelProviderSession //swiftlint:disable:this force_cast
            do {
                self.currentManager?.isOnDemandEnabled = UserDefaults.standard.onDemand
                try session.startTunnel()
                resolver.resolve(Result.fulfilled(()))
            } catch let error {
                os_log("error starting tunnel: %{public}@", log: Log.general, type: .error, error.localizedDescription)
                resolver.reject(error)
            }
        })
    }

    func disconnect() {
        configureVPN({ (_) in
            self.currentManager?.isOnDemandEnabled = false
            return nil
        }, completionHandler: { (_) in
            self.currentManager?.connection.stopVPNTunnel()
        })
    }
    
    func loadLog(completion: ((String) -> Void)? = nil) {
        guard let vpn = currentManager?.connection as? NETunnelProviderSession else {
            return
        }
        try? vpn.sendProviderMessage(TunnelKitProvider.Message.requestLog.data) { (data) in
            guard let log = String(data: data!, encoding: .utf8) else {
                return
            }
            
            completion?(log)
        }
    }
    
    func configureVPN(_ configure: @escaping (NETunnelProviderManager) -> NETunnelProviderProtocol?, completionHandler: @escaping (Error?) -> Void) {
        reloadCurrentManager { (error) in
            if let error = error {
                os_log("error reloading preferences: %{public}@", log: Log.general, type: .error, error.localizedDescription)
                completionHandler(error)
                return
            }
            
            let manager = self.currentManager!
            if let protocolConfiguration = configure(manager) {
                manager.protocolConfiguration = protocolConfiguration
            }
            manager.isEnabled = true
            manager.onDemandRules = [NEOnDemandRuleConnect()]
            
            manager.saveToPreferences { (error) in
                if let error = error {
                    os_log("error saving preferences: %{public}@", log: Log.general, type: .error, error.localizedDescription)
                    completionHandler(error)
                    return
                }
                
                if let protocolConfiguration = manager.protocolConfiguration as? NETunnelProviderProtocol {
                    UserDefaults.standard.configuredProfileId = (protocolConfiguration.providerConfiguration?[profileIdKey] as! String) //swiftlint:disable:this force_cast
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
            
            for man in managers! {
                if let prot = man.protocolConfiguration as? NETunnelProviderProtocol {
                    if prot.providerBundleIdentifier == self.vpnBundle {
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
}
