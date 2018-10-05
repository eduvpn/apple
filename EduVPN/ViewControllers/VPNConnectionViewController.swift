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

protocol VPNConnectionViewControllerDelegate: class {
}

class VPNConnectionViewController: UIViewController {
    weak var delegate: VPNConnectionViewControllerDelegate?

    static let APPGROUP = "group.nl.eduvpn.app.EduVPN.test.appforce1"

    static let VPNBUNDLE = "nl.eduvpn.app.EduVPN.test.appforce1.EduVPNTunnelExtension"

    static let CIPHER: SessionProxy.Cipher = .aes128cbc

    static let DIGEST: SessionProxy.Digest = .sha1

//    static let HANDSHAKE: SessionProxy.Handshake = .rsa2048

    static let RENEG: Int? = nil

    var username: String?

    var password: String?

    var server: String?

    var domain: String?

    var port: String?

    var tcp: Bool = false

    @IBOutlet var buttonConnection: UIButton!

    @IBOutlet var textLog: UITextView!

    @IBOutlet weak var notificationsSegment: UIView!
    @IBOutlet weak var logSegment: UIView!

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

        notificationsSegment.isHidden = false
        logSegment.isHidden = true

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

        server = ""
        domain = "vpn.tuxed.net"
        //        textServer.text = "159.122.133.238"
        //        textDomain.text = ""
        port = "1197"
        tcp = false
        username = "jeroen@leenarts.net"
        password = "VDvQpUaahigL6W"

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(VPNStatusDidChange(notification:)),
                                               name: .NEVPNStatusDidChange,
                                               object: nil)

        reloadCurrentManager(nil)
    }

    @IBAction func displayToggle(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            notificationsSegment.isHidden = false
            logSegment.isHidden = true
        case 1:
            notificationsSegment.isHidden = true
            logSegment.isHidden = false
        default:
            preconditionFailure("Unknown index \(sender.selectedSegmentIndex)")
        }
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

            let endpoint = TunnelKitProvider.AuthenticatedEndpoint(
                hostname: hostname,
                port: port,
                username: username,
                password: password
            )

            var builder = PIATunnelProvider.ConfigurationBuilder(appGroup: VPNConnectionViewController.APPGROUP)
            builder.socketType = (self.tcp ? .tcp : .udp)
            builder.cipher = VPNConnectionViewController.CIPHER
            builder.digest = VPNConnectionViewController.DIGEST
//            builder.handshake = .custom
            builder.mtu = 1500
            builder.ca = CryptoContainer(pem:"""
            -----BEGIN CERTIFICATE-----
            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
            XxuPeGGMYTQP3MPveijYdFJbp3MMb996
            -----END CERTIFICATE-----
            """)
            builder.clientCertificate = CryptoContainer(pem:"""
            -----BEGIN CERTIFICATE-----
            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
            uM92Txg11uLAoMV4P3NaU8rzcRP+bkhtFTWzCzw=
            -----END CERTIFICATE-----
            """)
            builder.clientKey = CryptoContainer(pem:"""
            -----BEGIN PRIVATE KEY-----
            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
            94T4HiQemtOnW1LkelRmB9xp5EpEXA==
            -----END PRIVATE KEY-----
            """)
            builder.renegotiatesAfterSeconds = VPNConnectionViewController.RENEG
            builder.shouldDebug = true
            builder.debugLogKey = "Log"

            let configuration = builder.build()
            return try! configuration.generatedTunnelProtocol(withBundleIdentifier: VPNConnectionViewController.VPNBUNDLE, appGroup: VPNConnectionViewController.APPGROUP, endpoint: endpoint)//swiftlint:disable:this force_try
        }, completionHandler: { (error) in
            if let error = error {
                os_log("configure error: %{public}@", log: Log.general, type: .error, error.localizedDescription)
                return
            }
            let session = self.currentManager?.connection as! NETunnelProviderSession //swiftlint:disable:this force_cast
            do {
                try session.startTunnel()
            } catch let error {
                os_log("error starting tunnel: %{public}@", log: Log.general, type: .error, error.localizedDescription)
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
        try? vpn.sendProviderMessage(TunnelKitProvider.Message.requestLog.data) { (data) in
            guard let log = String(data: data!, encoding: .utf8) else {
                return
            }
            self.textLog.text = log
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
            os_log("VPNStatusDidChange", log: Log.general, type: .debug)
            return
        }
        os_log("VPNStatusDidChange: %{public}@", log: Log.general, type: .debug, description(for: status))
        self.status = status
        updateButton()
    }
}

extension VPNConnectionViewController: Identifyable {}
