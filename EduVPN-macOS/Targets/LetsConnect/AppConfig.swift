//
//  AppConfig.swift
//  LetsConnect
//
//  Created by Johan Kool on 10/09/2018.
//  Copyright © 2017-2019 Commons Conservancy.
//

struct AppConfig: AppConfigType {
    
    var appName: String {
        return "Let's Connect!"
    }
    
    var clientId: String {
        return "org.letsconnect-vpn.app.macos"
    }
    
    var apiDiscoveryEnabled: Bool {
        return false
    }
}
