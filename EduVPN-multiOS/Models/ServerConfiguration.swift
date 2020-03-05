//
//  ServerConfiguration.swift
//  EduVPN
//

import Foundation

// Sample JSON:
//{
//    "peerId": 4,
//    "keepAliveTimeout": 60,
//    "ipv6": {
//        "defaultGateway": "2001:610:450:30::2:1",
//        "routes": [
//
//        ],
//        "addressPrefixLength": 112,
//        "address": "2001:610:450:30::2:101a"
//    },
//    "cipher": "AES-256-GCM",
//    "ipv4": {
//        "addressMask": "255.255.255.224",
//        "defaultGateway": "145.90.227.65",
//        "routes": [
//
//        ],
//        "address": "145.90.227.92"
//    },
//    "dnsServers": [
//        "192.87.106.106",
//        "192.87.36.36",
//        "2001:610:1:800a:192:87:106:106",
//        "2001:610:3:200a:192:87:36:36"
//    ],
//    "keepAliveInterval": 10,
//    "routingPolicies": [
//        "IPv4",
//        "IPv6"
//    ]
//}

struct ServerConfiguration: Codable {
    let ipv4: IPConfiguration?
    let ipv6: IPConfiguration?
}

struct IPConfiguration: Codable {
    let addressMask: String?
    let defaultGateway: String?
    let address: String?
}
