//
//  ConnectionService.swift
//  eduVPN 2
//
//  Created by Johan Kool on 28/05/2020.
//

import Foundation

protocol ConnectionServiceType {
    func setConnectionEnabled(_ enabled: Bool, server: AnyObject, profile: AnyObject)
    func relogin(server: AnyObject)
}

class ConnectionService: ConnectionServiceType {
    
    func setConnectionEnabled(_ enabled: Bool, server: AnyObject, profile: AnyObject) {
        
    }
    
    func relogin(server: AnyObject) {
        
    }
    
}
