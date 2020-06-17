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
        self.connectionState = ConnectionState(name: "Test", icon: nil, support: nil, connectionImage: Image(named: "Test")!, connectionStatus: "Connecting…", canClose: true, hasProfilesSection: false, profiles: [ProfileState(profileIdentifier: "foo", name: "Profile", enabled: false)], showsRenewSessionButton: false, showsConnectionInfo: false)
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
    }
    
    var updateConnectionHandler: ((ConnectionState) -> Void)?
    var updateConnectionInfoHandler: ((ConnectionInfoState) -> Void)?
    
    private var connectionState: ConnectionState
    
    func toggleProfile(_ index: Int, enabled: Bool) {
        connectionState.profiles[index].enabled = enabled
        // Disable others…
        
        updateConnectionHandler?(connectionState)
    }
    
    func renewSession() {
        
    }
    
    func toggleConnectionInfo(visible: Bool) {
        connectionState.showsConnectionInfo = visible
        updateConnectionHandler?(connectionState)
        
        if visible {
            // Start sending connection info updates
            
        } else {
            // Stop sending connection info updates
            
        }
    }
    
}
