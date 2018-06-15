//
//  VPNConnectionViewController.swift
//  EduVPN
//
//  Created by Jeroen Leenarts on 24-09-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

//TODO see https://github.com/pia-foss/tunnel-apple/blob/d4bd4fb6ad9a0e9b290f6b4137b5c6f30396a81c/Demo/BasicTunnel-iOS/ViewController.swift

import UIKit
import NetworkExtension
import PIATunnel

protocol VPNConnectionViewControllerDelegate: class {
}

class VPNConnectionViewController: UIViewController {
    weak var delegate: VPNConnectionViewControllerDelegate?

    static let APPGROUP = "group.nl.eduvpn.app.EduVPN.test.appforce1"

    static let VPNBUNDLE = "nl.eduvpn.app.EduVPN.test.appforce1.EduVPNTunnelExtension"

    static let CIPHER: PIATunnelProvider.Cipher = .aes128cbc

    static let DIGEST: PIATunnelProvider.Digest = .sha1

    static let HANDSHAKE: PIATunnelProvider.Handshake = .rsa2048

    static let RENEG: Int? = nil

    var username: String?

    var password: String?

    var server: String?

    var domain: String?

    var port: String?

    var tcp: Bool = false

    @IBOutlet var buttonConnection: UIButton!

    @IBOutlet var textLog: UITextView!

    var currentManager: NETunnelProviderManager?

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
    @IBOutlet weak var providerNameLabel: UILabel!
    @IBOutlet weak var profileNameLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()

        profileNameLabel.text = profile.profileId
        providerNameLabel.text = profile.displayNames?.localizedValue ?? profile.api?.instance?.displayNames?.localizedValue ?? profile.api?.instance?.baseUri
        if let logo = profile.api?.instance?.logos?.localizedValue, let logoUri = URL(string: logo) {
            providerImage.af_setImage(withURL: logoUri)
        } else if let providerTypeString = profile.api?.instance?.providerType, providerTypeString == ProviderType.other.rawValue {
            providerImage.image = #imageLiteral(resourceName: "external_provider")
        } else {
            providerImage.af_cancelImageRequest()
            providerImage.image = nil
        }

        server = "germany"
        domain = "privateinternetaccess.com"
        //        textServer.text = "159.122.133.238"
        //        textDomain.text = ""
        port = "8080"
        tcp = false
        username = "myusername"
        password = "mypassword"

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(VPNStatusDidChange(notification:)),
                                               name: .NEVPNStatusDidChange,
                                               object: nil)

        reloadCurrentManager(nil)
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

    @IBAction func tcpClicked(_ sender: Any) {
        if tcp {
            port = "443"
        } else {
            port = "8080"
        }
    }

    func connect() {
        guard let server = server, let domain = domain, let port = port, let username = username, let password = password else {
            return
        }
        let hostname = ((domain == "") ? server : [server, domain].compactMap { $0 }.joined(separator: "."))

        configureVPN({ (_) in
//            self.currentManager?.isOnDemandEnabled = true
//            self.currentManager?.onDemandRules = [NEOnDemandRuleConnect()]

            let endpoint = PIATunnelProvider.AuthenticatedEndpoint(
                hostname: hostname,
                port: port,
                username: username,
                password: password
            )

            var builder = PIATunnelProvider.ConfigurationBuilder(appGroup: VPNConnectionViewController.APPGROUP)
            builder.socketType = (self.tcp ? .tcp : .udp)
            builder.cipher = VPNConnectionViewController.CIPHER
            builder.digest = VPNConnectionViewController.DIGEST
            builder.handshake = VPNConnectionViewController.HANDSHAKE
            builder.mtu = 1350
            builder.renegotiatesAfterSeconds = VPNConnectionViewController.RENEG
            builder.shouldDebug = true
            builder.debugLogKey = "Log"

            let configuration = builder.build()
            return try! configuration.generatedTunnelProtocol(withBundleIdentifier: VPNConnectionViewController.VPNBUNDLE, endpoint: endpoint)//swiftlint:disable:this force_try
        }, completionHandler: { (error) in
            if let error = error {
                print("configure error: \(error)")
                return
            }
            let session = self.currentManager?.connection as! NETunnelProviderSession //swiftlint:disable:this force_cast
            do {
                try session.startTunnel()
            } catch let error {
                print("error starting tunnel: \(error)")
            }
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
        try? vpn.sendProviderMessage(PIATunnelProvider.Message.requestLog.data) { (data) in
            guard let log = String(data: data!, encoding: .utf8) else {
                return
            }
            self.textLog.text = log
        }
    }

    func configureVPN(_ configure: @escaping (NETunnelProviderManager) -> NETunnelProviderProtocol?, completionHandler: @escaping (Error?) -> Void) {
        reloadCurrentManager { (error) in
            if let error = error {
                print("error reloading preferences: \(error)")
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
                    print("error saving preferences: \(error)")
                    completionHandler(error)
                    return
                }
                print("saved preferences")
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
        case .connected, .connecting:
            buttonConnection.setTitle("Disconnect", for: .normal)

        case .disconnected:
            buttonConnection.setTitle("Connect", for: .normal)

        case .disconnecting:
            buttonConnection.setTitle("Disconnecting", for: .normal)

        default:
            break
        }
    }

    @objc private func VPNStatusDidChange(notification: NSNotification) {
        guard let status = currentManager?.connection.status else {
            print("VPNStatusDidChange")
            return
        }
        print("VPNStatusDidChange: \(description(for: status))")
        self.status = status
        updateButton()
    }
}

extension VPNConnectionViewController: Identifyable {}
