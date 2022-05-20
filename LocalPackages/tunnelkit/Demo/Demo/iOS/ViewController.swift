//
//  ViewController.swift
//  Demo
//
//  Created by Davide De Rosa on 2/11/17.
//  Copyright (c) 2021 Davide De Rosa. All rights reserved.
//
//  https://github.com/keeshux
//
//  This file is part of TunnelKit.
//
//  TunnelKit is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  TunnelKit is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with TunnelKit.  If not, see <http://www.gnu.org/licenses/>.
//

import UIKit
import TunnelKitCore
import TunnelKitAppExtension
import TunnelKitManager
import TunnelKitOpenVPN

private let appGroup = "group.com.algoritmico.TunnelKit.Demo"

private let tunnelIdentifier = "com.algoritmico.ios.TunnelKit.Demo.Tunnel"

class ViewController: UIViewController, URLSessionDataDelegate {
    @IBOutlet var textUsername: UITextField!
    
    @IBOutlet var textPassword: UITextField!
    
    @IBOutlet var textServer: UITextField!
    
    @IBOutlet var textDomain: UITextField!
    
    @IBOutlet var textPort: UITextField!
    
    @IBOutlet var switchTCP: UISwitch!
    
    @IBOutlet var buttonConnection: UIButton!

    @IBOutlet var textLog: UITextView!

    private let vpn = OpenVPNProvider(bundleIdentifier: tunnelIdentifier)
    
    private let keychain = Keychain(group: appGroup)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        textServer.text = "es"
        textDomain.text = "lazerpenguin.com"
        textPort.text = "443"
        switchTCP.isOn = false
        textUsername.text = ""
        textPassword.text = ""
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(VPNStatusDidChange(notification:)),
            name: VPN.didChangeStatus,
            object: nil
        )
        
        vpn.prepare(completionHandler: nil)

        testFetchRef()
    }
    
    @IBAction func connectionClicked(_ sender: Any) {
        switch vpn.status {
        case .disconnected:
            connect()
            
        case .connected, .connecting, .disconnecting:
            disconnect()
        }
    }
    
    @IBAction func tcpClicked(_ sender: Any) {
    }
    
    func connect() {
        let server = textServer.text!
        let domain = textDomain.text!
        let hostname = ((domain == "") ? server : [server, domain].joined(separator: "."))
        let port = UInt16(textPort.text!)!
        let socketType: SocketType = switchTCP.isOn ? .tcp : .udp

        let credentials = OpenVPN.Credentials(textUsername.text!, textPassword.text!)
        let cfg = Configuration.make(hostname: hostname, port: port, socketType: socketType)
        let proto = try! cfg.generatedTunnelProtocol(
            withBundleIdentifier: tunnelIdentifier,
            appGroup: appGroup,
            context: tunnelIdentifier,
            credentials: credentials
        )
        let neCfg = NetworkExtensionVPNConfiguration(title: "BasicTunnel", protocolConfiguration: proto, onDemandRules: [])
        vpn.reconnect(configuration: neCfg) { (error) in
            if let error = error {
                print("configure error: \(error)")
                return
            }
        }
    }
    
    func disconnect() {
        vpn.disconnect(completionHandler: nil)
    }

    @IBAction func displayLog() {
        vpn.requestDebugLog(fallback: { "" }) { (log) in
            self.textLog.text = log
        }
    }
    
    func updateButton() {
        switch vpn.status {
        case .connected, .connecting:
            buttonConnection.setTitle("Disconnect", for: .normal)
            
        case .disconnected:
            buttonConnection.setTitle("Connect", for: .normal)
            
        case .disconnecting:
            buttonConnection.setTitle("Disconnecting", for: .normal)
        }
    }
    
    @objc private func VPNStatusDidChange(notification: NSNotification) {
        print("VPNStatusDidChange: \(vpn.status)")
        updateButton()
    }
    
    private func testFetchRef() {
        let keychain = Keychain(group: appGroup)
        let username = "foo"
        let password = "bar"
        
        guard let ref = try? keychain.set(password: password, for: username, context: tunnelIdentifier) else {
            print("Couldn't set password")
            return
        }
        guard let fetchedPassword = try? Keychain.password(forReference: ref) else {
            print("Couldn't fetch password")
            return
        }

        print("\(username) -> \(password)")
        print("\(username) -> \(fetchedPassword)")
    }
}
