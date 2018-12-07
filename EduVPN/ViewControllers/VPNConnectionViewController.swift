//
//  VPNConnectionViewController.swift
//  EduVPN
//
//  Created by Jeroen Leenarts on 24-09-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

//TODO see https://github.com/pia-foss/tunnel-apple/blob/d4bd4fb6ad9a0e9b290f6b4137b5c6f30396a81c/Demo/BasicTunnel-iOS/ViewController.swift

import UIKit
import os.log
import NetworkExtension
import TunnelKit
import PromiseKit

private let profileIdKey = "EduVPNprofileId"

protocol VPNConnectionViewControllerDelegate: class {
    func profileConfig(for profile: Profile) -> Promise<URL>
    @discardableResult func systemMessages(for profile: Profile) -> Promise<Messages>
    @discardableResult func userMessages(for profile: Profile) -> Promise<Messages>
}

class VPNConnectionViewController: UIViewController {
    weak var delegate: VPNConnectionViewControllerDelegate?
    
    private let intervalFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        return formatter
    }()
    
    static let APPGROUP = "group.nl.eduvpn.app.EduVPN.test.appforce1"

    static let VPNBUNDLE = "nl.eduvpn.app.EduVPN.test.appforce1.EduVPNTunnelExtension"

    @IBOutlet var buttonConnection: UIButton!
    
    @IBOutlet weak var notificationLabel: UILabel!
    
    @IBOutlet var durationLabel: UILabel!
    
    @IBOutlet var outBytesLabel: UILabel!
    
    @IBOutlet var inBytesLabel: UILabel!

    var currentManager: NETunnelProviderManager?
    
    private var connectionInfoUpdateTimer: Timer?

    var status = NEVPNStatus.invalid {
        didSet {
            switch status {
            case .connected:
                statusImage.image = #imageLiteral(resourceName: "connected")
            case .connecting, .disconnecting, .reasserting:
                statusImage.image = #imageLiteral(resourceName: "connecting")
            case .disconnected, .invalid:
                statusImage.image = #imageLiteral(resourceName: "not-connected")
            }
        }
    }

    func description(for status: NEVPNStatus) -> String {
        switch status {
        case .connected:
            return "Connected"
        case .connecting:
            return "Connecting"
        case .disconnected:
            return "Disconnected"
        case .disconnecting:
            return "Disconnecting"
        case .invalid:
            return "Invalid"
        case .reasserting:
            return "Reasserting"
        }
    }

    var profile: Profile!

    @IBOutlet weak var statusImage: UIImageView!

    @IBOutlet weak var providerImage: UIImageView!
    @IBOutlet weak var profileNameLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()

        profileNameLabel.text = profile.profileId
        if let logo = profile.api?.instance?.logos?.localizedValue, let logoUri = URL(string: logo) {
            providerImage.af_setImage(withURL: logoUri)
        } else if let providerTypeString = profile.api?.instance?.providerType, providerTypeString == ProviderType.other.rawValue {
            providerImage.af_cancelImageRequest()
            providerImage.image = nil
        } else {
            providerImage.af_cancelImageRequest()
            providerImage.image = nil
        }

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(VPNStatusDidChange(notification:)),
                                               name: .NEVPNStatusDidChange,
                                               object: nil)

        reloadCurrentManager(nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { [weak self] (_) in
            self?.updateConnectionInfo()
        })
        if let concreteDelegate = delegate {
            firstly { () -> Promise<Messages> in
                return concreteDelegate.systemMessages(for: profile)
            }.then({ [weak self] (systemMessages) -> Guarantee<Void> in
                if let displayString = systemMessages.displayString {
                    if let existingText = self?.notificationLabel.text, !existingText.isEmpty  {
                        self?.notificationLabel.text = [existingText, displayString].joined(separator: "\n\n")
                    } else {
                        self?.notificationLabel.text = displayString
                    }
                }
                return Guarantee<Void>()
            })
            
            firstly { () -> Promise<Messages> in
                return concreteDelegate.userMessages(for: profile)
            }.then({ [weak self] (userMessages) -> Guarantee<Void> in
                if let displayString = userMessages.displayString {
                    if let existingText = self?.notificationLabel.text, !existingText.isEmpty {
                        self?.notificationLabel.text = [existingText, displayString].joined(separator: "\n\n")
                    } else {
                        self?.notificationLabel.text = displayString
                    }
                }
                return Guarantee<Void>()
            })
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        connectionInfoUpdateTimer?.invalidate()
        connectionInfoUpdateTimer = nil
    }
    
    @IBAction func closeClicked(_ sender: Any) {
        self.presentingViewController?.dismiss(animated: true, completion: nil)
    }

    @IBAction func connectionClicked(_ sender: Any) {
        let block = {
            switch self.status {
            case .invalid, .disconnected:
                self.connect()

            case .connected, .connecting:
                self.disconnect()

            default:
                break
            }
        }

        if status == .invalid {
            reloadCurrentManager({ (_) in
                block()
            })
        } else {
            block()
        }
    }

    func connect() {

        _ = delegate?.profileConfig(for: profile).then({ (configUrl) -> Promise<Void> in
            let parseResult = try! ConfigurationParser.parsed(fromURL: configUrl)

            return Promise(resolver: { (resolver) in
                self.configureVPN({ [weak self] (_) in
                    let sessionConfig = parseResult.configuration.builder().build()
                    var builder = TunnelKitProvider.ConfigurationBuilder(sessionConfiguration: sessionConfig)
                    builder.endpointProtocols = parseResult.protocols
                    let configuration = builder.build()

                    let tunnelProviderProtocolConfiguration = try! configuration.generatedTunnelProtocol(
                        withBundleIdentifier: VPNConnectionViewController.VPNBUNDLE,
                        appGroup: VPNConnectionViewController.APPGROUP,
                        hostname: parseResult.hostname)//swiftlint:disable:this force_try
                    
                    tunnelProviderProtocolConfiguration.providerConfiguration?[profileIdKey] = self?.profile.uuid?.uuidString
                    
                    return tunnelProviderProtocolConfiguration

                }, completionHandler: { (error) in
                    if let error = error {
                        os_log("configure error: %{public}@", log: Log.general, type: .error, error.localizedDescription)
                        resolver.reject(error)
                        return
                    }
                    let session = self.currentManager?.connection as! NETunnelProviderSession //swiftlint:disable:this force_cast
                    do {
                        try session.startTunnel()
                        resolver.resolve(Result.fulfilled(()))
                    } catch let error {
                        os_log("error starting tunnel: %{public}@", log: Log.general, type: .error, error.localizedDescription)
                        resolver.reject(error)
                    }
                })
            })
        })
    }

    func disconnect() {
        configureVPN({ (_) in
//            self.currentManager?.isOnDemandEnabled = false
            return nil
        }, completionHandler: { (_) in
            self.currentManager?.connection.stopVPNTunnel()
        })
    }

    @IBAction func displayLog() {
        guard let vpn = currentManager?.connection as? NETunnelProviderSession else {
            return
        }
        try? vpn.sendProviderMessage(TunnelKitProvider.Message.requestLog.data) { (data) in
            guard let log = String(data: data!, encoding: .utf8) else {
                return
            }
            //TODO display log
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

            manager.saveToPreferences { (error) in
                if let error = error {
                    os_log("error saving preferences: %{public}@", log: Log.general, type: .error, error.localizedDescription)
                    completionHandler(error)
                    return
                }
                
                if let protocolConfiguration = manager.protocolConfiguration as? NETunnelProviderProtocol {
                    UserDefaults.standard.configuredProfileId = (protocolConfiguration.providerConfiguration?[profileIdKey] as! String)
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
                    if prot.providerBundleIdentifier == VPNConnectionViewController.VPNBUNDLE {
                        manager = man
                        break
                    }
                }
            }

            if manager == nil {
                manager = NETunnelProviderManager()
            }

            self.currentManager = manager
            self.status = manager!.connection.status
            self.updateButton()
            completionHandler?(nil)
        }
    }

    func updateButton() {
        switch status {
        case .connected, .connecting, .disconnecting, .reasserting:
            buttonConnection.setTitle("Disconnect", for: .normal)

        case .disconnected, .invalid:
            buttonConnection.setTitle("Connect", for: .normal)
        }
    }

    @objc private func VPNStatusDidChange(notification: NSNotification) {
        guard let status = currentManager?.connection.status else {
            os_log("VPNStatusDidChange", log: Log.general, type: .debug)
            return
        }
        os_log("VPNStatusDidChange: %{public}@", log: Log.general, type: .debug, description(for: status))
        self.status = status
        updateButton()
    }
    
    func updateConnectionInfo() {
        guard let vpn = currentManager?.connection as? NETunnelProviderSession else {
            return
        }
        let intervalString = vpn.connectedDate.flatMap {
            intervalFormatter.string(from: Date().timeIntervalSinceReferenceDate - $0.timeIntervalSinceReferenceDate)
        }
        
        durationLabel.text = intervalString
        
        try? vpn.sendProviderMessage(TunnelKitProvider.Message.dataCount.data) { [weak self] (data) in
            let dataCount = data?.withUnsafeBytes({ (pointer:UnsafePointer<(UInt64, UInt64)>) -> (UInt64, UInt64) in
                pointer.pointee
            })
            if let inByteCount = dataCount?.0 {
                self?.inBytesLabel.text = ByteCountFormatter.string(fromByteCount: Int64(inByteCount), countStyle: .binary )
            } else {
                self?.inBytesLabel.text = nil
            }
            if let outByteCount = dataCount?.1 {
                self?.outBytesLabel.text = ByteCountFormatter.string(fromByteCount: Int64(outByteCount), countStyle: .binary )
            } else {
                self?.outBytesLabel.text = nil
            }
        }
    }
}

extension VPNConnectionViewController: Identifyable {}
