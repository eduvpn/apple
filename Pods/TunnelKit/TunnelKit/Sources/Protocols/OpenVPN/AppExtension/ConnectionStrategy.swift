//
//  ConnectionStrategy.swift
//  TunnelKit
//
//  Created by Davide De Rosa on 6/18/18.
//  Copyright (c) 2019 Davide De Rosa. All rights reserved.
//
//  https://github.com/passepartoutvpn
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
//  This file incorporates work covered by the following copyright and
//  permission notice:
//
//      Copyright (c) 2018-Present Private Internet Access
//
//      Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
//      The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
//      THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

import Foundation
import NetworkExtension
import SwiftyBeaver

private let log = SwiftyBeaver.self

class ConnectionStrategy {
    private let hostname: String?

    private let prefersResolvedAddresses: Bool

    private var resolvedAddresses: [String]?
    
    private let endpointProtocols: [EndpointProtocol]
    
    private var currentProtocolIndex = 0

    init(configuration: OpenVPNTunnelProvider.Configuration) {
        hostname = configuration.sessionConfiguration.hostname
        prefersResolvedAddresses = (hostname == nil) || configuration.prefersResolvedAddresses
        resolvedAddresses = configuration.resolvedAddresses
        if prefersResolvedAddresses {
            guard !(resolvedAddresses?.isEmpty ?? true) else {
                fatalError("Either hostname or resolved addresses provided")
            }
        }
        guard var endpointProtocols = configuration.sessionConfiguration.endpointProtocols else {
            fatalError("No endpoints provided")
        }
        if configuration.sessionConfiguration.randomizeEndpoint ?? false {
            endpointProtocols.shuffle()
        }
        self.endpointProtocols = endpointProtocols
    }

    func createSocket(
        from provider: NEProvider,
        timeout: Int,
        preferredAddress: String? = nil,
        queue: DispatchQueue,
        completionHandler: @escaping (GenericSocket?, Error?) -> Void) {
        
        // reuse preferred address
        if let preferredAddress = preferredAddress {
            log.debug("Pick preferred address: \(preferredAddress.maskedDescription)")
            let socket = provider.createSocket(to: preferredAddress, protocol: currentProtocol())
            completionHandler(socket, nil)
            return
        }
        
        // use any resolved address
        if prefersResolvedAddresses, let resolvedAddress = anyResolvedAddress() {
            log.debug("Pick resolved address: \(resolvedAddress.maskedDescription)")
            let socket = provider.createSocket(to: resolvedAddress, protocol: currentProtocol())
            completionHandler(socket, nil)
            return
        }
        
        // fall back to DNS
        guard let hostname = hostname else {
            log.error("DNS resolution unavailable: no hostname provided!")
            completionHandler(nil, OpenVPNTunnelProvider.ProviderError.dnsFailure)
            return
        }
        log.debug("DNS resolve hostname: \(hostname.maskedDescription)")
        DNSResolver.resolve(hostname, timeout: timeout, queue: queue) { (addresses, error) in
            
            // refresh resolved addresses
            if let resolved = addresses, !resolved.isEmpty {
                self.resolvedAddresses = resolved

                log.debug("DNS resolved addresses: \(resolved.map { $0.maskedDescription })")
            } else {
                log.error("DNS resolution failed!")
            }

            guard let targetAddress = self.resolvedAddress(from: addresses) else {
                log.error("No resolved or fallback address available")
                completionHandler(nil, OpenVPNTunnelProvider.ProviderError.dnsFailure)
                return
            }

            let socket = provider.createSocket(to: targetAddress, protocol: self.currentProtocol())
            completionHandler(socket, nil)
        }
    }

    func tryNextProtocol() -> Bool {
        let next = currentProtocolIndex + 1
        guard next < endpointProtocols.count else {
            log.debug("No more protocols available")
            return false
        }
        currentProtocolIndex = next
        log.debug("Fall back to next protocol: \(currentProtocol())")
        return true
    }
    
    private func currentProtocol() -> EndpointProtocol {
        return endpointProtocols[currentProtocolIndex]
    }

    private func resolvedAddress(from addresses: [String]?) -> String? {
        guard let resolved = addresses, !resolved.isEmpty else {
            return anyResolvedAddress()
        }
        return resolved[0]
    }

    private func anyResolvedAddress() -> String? {
        guard let addresses = resolvedAddresses, !addresses.isEmpty else {
            return nil
        }
        let n = Int(arc4random() % UInt32(addresses.count))
        return addresses[n]
    }
}

private extension NEProvider {
    func createSocket(to address: String, protocol endpointProtocol: EndpointProtocol) -> GenericSocket {
        let endpoint = NWHostEndpoint(hostname: address, port: "\(endpointProtocol.port)")
        switch endpointProtocol.socketType {
        case .udp:
            let impl = createUDPSession(to: endpoint, from: nil)
            return NEUDPSocket(impl: impl)
            
        case .tcp:
            let impl = createTCPConnection(to: endpoint, enableTLS: false, tlsParameters: nil, delegate: nil)
            return NETCPSocket(impl: impl)
        }
    }
}
