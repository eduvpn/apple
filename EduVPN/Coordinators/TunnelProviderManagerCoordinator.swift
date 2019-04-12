//
//  TunnelProviderManagerCoordinator.swift
//  eduVPN
//
//  Created by Jeroen Leenarts on 13/12/2018.
//  Copyright © 2018 SURFNet. All rights reserved.
//

import Foundation
import os.log
import NetworkExtension
import TunnelKit
import PromiseKit
import CoreData

enum TunnelProviderManagerCoordinatorError: Error {
    case missingDelegate
}

private let profileIdKey = "EduVPNprofileId"

protocol TunnelProviderManagerCoordinatorDelegate: class {
    func profileConfig(for profile: Profile) -> Promise<URL>
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
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: UIApplication.willEnterForegroundNotification, object: nil)
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

    func configure(profile: Profile)  -> Promise<Void> {
        guard let delegate = delegate else {
            return Promise(error: TunnelProviderManagerCoordinatorError.missingDelegate)
        }
        return delegate.profileConfig(for: profile).then({ (configUrl) -> Promise<Void> in
            #if targetEnvironment(simulator)
            print("SIMULATOR DOES NOT SUPPORT NETWORK EXTENSIONS")
            return Promise.value(())
            #else
            let parseResult = try! ConfigurationParser.parsed(fromURL: configUrl) //swiftlint:disable:this force_try

            return Promise(resolver: { (resolver) in
                self.configureVPN({ (_) in
                    let sessionConfig = parseResult.configuration.builder().build()
                    var builder = TunnelKitProvider.ConfigurationBuilder(sessionConfiguration: sessionConfig)
                    builder.masksPrivateData = false
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
                    }
                    resolver.resolve(error)
                })
            })
            #endif
        })
    }

    func connect() -> Promise<Void> {
        #if targetEnvironment(simulator)
        print("SIMULATOR DOES NOT SUPPORT NETWORK EXTENSIONS")
        return Promise.value(())
        #else
        return Promise(resolver: { (resolver) in
            let session = self.currentManager?.connection as? NETunnelProviderSession
            do {
                self.currentManager?.isOnDemandEnabled = UserDefaults.standard.onDemand
                try session?.startTunnel()
                resolver.resolve(Result.fulfilled(()))
            } catch let error {
                os_log("error starting tunnel: %{public}@", log: Log.general, type: .error, error.localizedDescription)
                resolver.reject(error)
            }
        })
        #endif
    }

    func disconnect() -> Promise<Void> {
        #if targetEnvironment(simulator)
        print("SIMULATOR DOES NOT SUPPORT NETWORK EXTENSIONS")
        return Promise.value(())
        #else
        return Promise(resolver: { (resolver) in
            configureVPN({ (_) in
                self.currentManager?.isOnDemandEnabled = false
                return nil
            }, completionHandler: { (error) in
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

    @objc private func refresh() {
        reloadCurrentManager { [weak self] (_) in
            guard let status = self?.currentManager?.connection.status else {
                return
            }
            self?.delegate?.updateProfileStatus(with: status)
        }
    }

    @objc private func VPNStatusDidChange(notification: NSNotification) {
        guard let status = currentManager?.connection.status else {
            return
        }
        delegate?.updateProfileStatus(with: status)
    }
}
