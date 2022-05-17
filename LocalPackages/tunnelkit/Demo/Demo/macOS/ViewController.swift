//
//  ViewController.swift
//  Demo
//
//  Created by Davide De Rosa on 10/15/17.
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

import Cocoa
import TunnelKitCore
import TunnelKitAppExtension
import TunnelKitManager
import TunnelKitOpenVPN

private let appGroup = "DTDYD63ZX9.group.com.algoritmico.TunnelKit.Demo"

private let tunnelIdentifier = "com.algoritmico.macos.TunnelKit.Demo.Tunnel"

class ViewController: NSViewController {
    @IBOutlet var textUsername: NSTextField!
    
    @IBOutlet var textPassword: NSTextField!
    
    @IBOutlet var textServer: NSTextField!
    
    @IBOutlet var textDomain: NSTextField!
    
    @IBOutlet var textPort: NSTextField!
    
    @IBOutlet var buttonConnection: NSButton!
    
    private let vpn = OpenVPNProvider(bundleIdentifier: tunnelIdentifier)

    private let keychain = Keychain(group: appGroup)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        textServer.stringValue = "es"
        textDomain.stringValue = "lazerpenguin.com"
        textPort.stringValue = "443"
        textUsername.stringValue = ""
        textPassword.stringValue = ""
        
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
    
    func connect() {
        let server = textServer.stringValue
        let domain = textDomain.stringValue
        let hostname = ((domain == "") ? server : [server, domain].joined(separator: "."))
        let port = UInt16(textPort.stringValue)!

        let credentials = OpenVPN.Credentials(textUsername.stringValue, textPassword.stringValue)
        let cfg = Configuration.make(hostname: hostname, port: port, socketType: .udp)
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

    func updateButton() {
        switch vpn.status {
        case .connected, .connecting:
            buttonConnection.title = "Disconnect"
            
        case .disconnected:
            buttonConnection.title = "Connect"
            
        case .disconnecting:
            buttonConnection.title = "Disconnecting"
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

