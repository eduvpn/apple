//
//  ConnectionViewModel.swift
//  EduVPN
//
//  Created by Johan Kool on 28/05/2020.
//  Copyright © 2020 SURFNet. All rights reserved.
//

import Foundation

class ConnectionViewModel {
    
    let environment: Environment
    
    init(environment: Environment) {
        self.environment = environment
        self.connectionState = ConnectionState(name: "Test", icon: nil, support: nil, connectionImage: Image(named: "Test")!, connectionStatus: "Connecting…", canClose: true, hasProfilesSection: true, profiles: [ProfileState(profileIdentifier: "foo", name: "Profile 1", enabled: false), ProfileState(profileIdentifier: "bar", name: "Profile 2", enabled: false), ProfileState(profileIdentifier: "baz", name: "Profile 3", enabled: false)], showsRenewSessionButton: false, showsConnectionInfo: false)
    }
    
    struct ConnectionState {
        var name: String
        var icon: Image?
        var support: String?
        var connectionImage: Image
        var connectionStatus: String
        var connectionStatusDetail: String?
        var canClose: Bool
        var hasProfilesSection: Bool
        var profiles: [ProfileState]
        var showsRenewSessionButton: Bool
        var showsConnectionInfo: Bool
    }
    
    struct ProfileState {
        var profileIdentifier: String
        var name: String
        var enabled: Bool
    }
    
    struct ConnectionInfoState {
        var duration: String
        var download: String
        var upload: String
        var ipv4Address: String
        var ipv6Address: String
        
        static var empty: ConnectionInfoState {
            return ConnectionInfoState(duration: "-:--:--", download: "--", upload: "--", ipv4Address: "--", ipv6Address: "--")
        }
    }
    
    var updateConnectionHandler: ((ConnectionState) -> Void)? {
        didSet {
            updateConnectionHandler?(connectionState)
        }
    }
    
    var updateConnectionInfoHandler: ((ConnectionInfoState) -> Void)? {
        didSet {
            updateConnectionInfoHandler?(ConnectionInfoState.empty)
        }
    }
    
    private var connectionState: ConnectionState
    
    func toggleProfile(_ index: Int, enabled: Bool) {
        for otherIndex in connectionState.profiles.indices {
            if otherIndex == index {
                connectionState.profiles[otherIndex].enabled = enabled
            } else {
                connectionState.profiles[otherIndex].enabled = false
            }
        }
        connectionState.canClose = !enabled
        connectionState.connectionStatus = enabled ? "Connected" : "Disconnected"

        updateConnectionHandler?(connectionState)
    }
    
    func renewSession() {
        
    }
    
    func toggleConnectionInfo(visible: Bool) {
        connectionState.showsConnectionInfo = visible
        updateConnectionHandler?(connectionState)
        
        if visible {
            // Start sending connection info updates
            let connectionInfoState = ConnectionInfoState(duration: "0:00:12", download: "2 KB", upload: "14 KB", ipv4Address: "127.0.0.1", ipv6Address: "abc.def.ghi.jkl.mno")
            updateConnectionInfoHandler?(connectionInfoState)
            
        } else {
            // Stop sending connection info updates
            updateConnectionInfoHandler?(ConnectionInfoState.empty)
        }
    }
    
}
