//
//  NETCPLink.swift
//  TunnelKit
//
//  Created by Davide De Rosa on 5/23/19.
//  Copyright (c) 2021 Davide De Rosa. All rights reserved.
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

import Foundation
import NetworkExtension
import TunnelKitCore
import TunnelKitAppExtension
import CTunnelKitOpenVPNProtocol

class NETCPLink: LinkInterface {
    private let impl: NWTCPConnection
    
    private let maxPacketSize: Int
    
    let xorMask: UInt8
    
    init(impl: NWTCPConnection, maxPacketSize: Int? = nil, xorMask: UInt8?) {
        self.impl = impl
        self.maxPacketSize = maxPacketSize ?? (512 * 1024)
        self.xorMask = xorMask ?? 0
    }
    
    // MARK: LinkInterface
    
    let isReliable: Bool = true
    
    var remoteAddress: String? {
        return (impl.remoteAddress as? NWHostEndpoint)?.hostname
    }
    
    var packetBufferSize: Int {
        return maxPacketSize
    }
    
    func setReadHandler(queue: DispatchQueue, _ handler: @escaping ([Data]?, Error?) -> Void) {
        loopReadPackets(queue, Data(), handler)
    }
    
    private func loopReadPackets(_ queue: DispatchQueue, _ buffer: Data, _ handler: @escaping ([Data]?, Error?) -> Void) {
        
        // WARNING: runs in Network.framework queue
        impl.readMinimumLength(2, maximumLength: packetBufferSize) { [weak self] (data, error) in
            guard let self = self else {
                return
            }
            queue.sync {
                guard (error == nil), let data = data else {
                    handler(nil, error)
                    return
                }
                
                var newBuffer = buffer
                newBuffer.append(contentsOf: data)
                var until = 0
                let packets = PacketStream.packets(fromStream: newBuffer, until: &until, xorMask: self.xorMask)
                newBuffer = newBuffer.subdata(in: until..<newBuffer.count)
                self.loopReadPackets(queue, newBuffer, handler)
                
                handler(packets, nil)
            }
        }
    }
    
    func writePacket(_ packet: Data, completionHandler: ((Error?) -> Void)?) {
        let stream = PacketStream.stream(fromPacket: packet, xorMask: xorMask)
        impl.write(stream) { (error) in
            completionHandler?(error)
        }
    }
    
    func writePackets(_ packets: [Data], completionHandler: ((Error?) -> Void)?) {
        let stream = PacketStream.stream(fromPackets: packets, xorMask: xorMask)
        impl.write(stream) { (error) in
            completionHandler?(error)
        }
    }
}

extension NETCPSocket: LinkProducer {
    public func link(xorMask: UInt8?) -> LinkInterface {
        return NETCPLink(impl: impl, maxPacketSize: nil, xorMask: xorMask)
    }
}
