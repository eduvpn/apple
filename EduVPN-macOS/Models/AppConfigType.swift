//
//  AppConfigType.swift
//  eduVPN
//
//  Created by Johan Kool on 10/09/2018.
//  Copyright © 2017-2019 Commons Conservancy.
//

protocol AppConfigType {
    var appName: String { get }
    var clientId: String { get }
    
    var apiDiscoveryEnabled: Bool { get }
}
