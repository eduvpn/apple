//
//  NEUDPLink.swift
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

class NEUDPLink: LinkInterface {
    private let impl: NWUDPSession
    
    private let maxDatagrams: Int
    
    let xorMask: UInt8
    
    init(impl: NWUDPSession, maxDatagrams: Int? = nil, xorMask: UInt8?) {
        self.impl = impl
        self.maxDatagrams = maxDatagrams ?? 200
        self.xorMask = xorMask ?? 0
    }
    
    // MARK: LinkInterface
    
    let isReliable: Bool = false
    
    var remoteAddress: String? {
        return (impl.resolvedEndpoint as? NWHostEndpoint)?.hostname
    }
    
    var packetBufferSize: Int {
        return maxDatagrams
    }
    
    func setReadHandler(queue: DispatchQueue, _ handler: @escaping ([Data]?, Error?) -> Void) {
        
        // WARNING: runs in Network.framework queue
        impl.setReadHandler({ [weak self] packets, error in
            guard let self = self else {
                return
            }
            var packetsToUse: [Data]?
            if let packets = packets, self.xorMask != 0 {
                packetsToUse = packets.map { packet in
                    Data(bytes: packet.map { $0 ^ self.xorMask }, count: packet.count)
                }
            } else {
                packetsToUse = packets
            }
            queue.sync {
                handler(packetsToUse, error)
            }
        }, maxDatagrams: maxDatagrams)
    }
    
    func writePacket(_ packet: Data, completionHandler: ((Error?) -> Void)?) {
        var dataToUse: Data
        if xorMask != 0 {
            dataToUse = Data(bytes: packet.map { $0 ^ xorMask }, count: packet.count)
        } else {
            dataToUse = packet
        }
        impl.writeDatagram(dataToUse) { error in
            completionHandler?(error)
        }
    }
    
    func writePackets(_ packets: [Data], completionHandler: ((Error?) -> Void)?) {
        var packetsToUse: [Data]
        if xorMask != 0 {
            packetsToUse = packets.map { packet in
                Data(bytes: packet.map { $0 ^ xorMask }, count: packet.count)
            }
        } else {
            packetsToUse = packets
        }
        impl.writeMultipleDatagrams(packetsToUse) { error in
            completionHandler?(error)
        }
    }
}

extension NEUDPSocket: LinkProducer {
    public func link(xorMask: UInt8?) -> LinkInterface {
        return NEUDPLink(impl: impl, maxDatagrams: nil, xorMask: xorMask)
    }
}
