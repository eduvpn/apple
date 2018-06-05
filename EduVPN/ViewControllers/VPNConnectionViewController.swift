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

    @IBOutlet var textUsername: UITextField!

    @IBOutlet var textPassword: UITextField!

    @IBOutlet var textServer: UITextField!

    @IBOutlet var textDomain: UITextField!

    @IBOutlet var textPort: UITextField!

    @IBOutlet var switchTCP: UISwitch!

    @IBOutlet var buttonConnection: UIButton!

    @IBOutlet var textLog: UITextView!

    var currentManager: NETunnelProviderManager?

    var status = NEVPNStatus.invalid

    override func viewDidLoad() {
        super.viewDidLoad()

        textServer.text = "germany"
        textDomain.text = "privateinternetaccess.com"
        //        textServer.text = "159.122.133.238"
        //        textDomain.text = ""
        textPort.text = "8080"
        switchTCP.isOn = false
        textUsername.text = "myusername"
        textPassword.text = "mypassword"

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
        if switchTCP.isOn {
            textPort.text = "443"
        } else {
            textPort.text = "8080"
        }
    }

    func connect() {
        let server = textServer.text!
        let domain = textDomain.text!

        let hostname = ((domain == "") ? server : [server, domain].joined(separator: "."))
        let port = textPort.text!
        let username = textUsername.text!
        let password = textPassword.text!

        configureVPN({ (_) in
            //            manager.isOnDemandEnabled = true
            //            manager.onDemandRules = [NEOnDemandRuleConnect()]

            let endpoint = PIATunnelProvider.AuthenticatedEndpoint(
                hostname: hostname,
                port: port,
                username: username,
                password: password
            )

            var builder = PIATunnelProvider.ConfigurationBuilder(appGroup: VPNConnectionViewController.APPGROUP)
            builder.socketType = (self.switchTCP.isOn ? .tcp : .udp)
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
            //            manager.isOnDemandEnabled = false
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
        print("VPNStatusDidChange: \(status.rawValue)")
        self.status = status
        updateButton()
    }
}

extension VPNConnectionViewController: Identifyable {}
