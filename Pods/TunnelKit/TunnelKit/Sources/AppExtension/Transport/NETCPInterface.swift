//
//  NETCPInterface.swift
//  TunnelKit
//
//  Created by Davide De Rosa on 4/15/18.
//  Copyright (c) 2019 Davide De Rosa. All rights reserved.
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
//

import Foundation
import NetworkExtension
import SwiftyBeaver

private let log = SwiftyBeaver.self

class NETCPSocket: NSObject, GenericSocket {
    private static var linkContext = 0
    
    private let impl: NWTCPConnection
    
    init(impl: NWTCPConnection) {
        self.impl = impl
        isActive = false
        isShutdown = false
    }
    
    // MARK: GenericSocket
    
    private weak var queue: DispatchQueue?
    
    private var isActive: Bool
    
    private(set) var isShutdown: Bool
    
    var remoteAddress: String? {
        return (impl.remoteAddress as? NWHostEndpoint)?.hostname
    }
    
    var hasBetterPath: Bool {
        return impl.hasBetterPath
    }
    
    weak var delegate: GenericSocketDelegate?
    
    func observe(queue: DispatchQueue, activeTimeout: Int) {
        isActive = false
        
        self.queue = queue
        queue.schedule(after: .milliseconds(activeTimeout)) { [weak self] in
            guard let _self = self else {
                return
            }
            guard _self.isActive else {
                _self.delegate?.socketDidTimeout(_self)
                return
            }
        }
        impl.addObserver(self, forKeyPath: #keyPath(NWTCPConnection.state), options: [.initial, .new], context: &NETCPSocket.linkContext)
        impl.addObserver(self, forKeyPath: #keyPath(NWTCPConnection.hasBetterPath), options: .new, context: &NETCPSocket.linkContext)
    }
    
    func unobserve() {
        impl.removeObserver(self, forKeyPath: #keyPath(NWTCPConnection.state), context: &NETCPSocket.linkContext)
        impl.removeObserver(self, forKeyPath: #keyPath(NWTCPConnection.hasBetterPath), context: &NETCPSocket.linkContext)
    }
    
    func shutdown() {
        impl.writeClose()
        impl.cancel()
    }
    
    func upgraded() -> GenericSocket? {
        guard impl.hasBetterPath else {
            return nil
        }
        return NETCPSocket(impl: NWTCPConnection(upgradeFor: impl))
    }
    
    func link(withMTU mtu: Int) -> LinkInterface {
        return NETCPLink(impl: impl, mtu: mtu)
    }
    
    // MARK: Connection KVO (any queue)
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard (context == &NETCPSocket.linkContext) else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
//        if let keyPath = keyPath {
//            log.debug("KVO change reported (\(anyPointer(object)).\(keyPath))")
//        }
        queue?.async {
            self.observeValueInTunnelQueue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
    
    private func observeValueInTunnelQueue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
//        if let keyPath = keyPath {
//            log.debug("KVO change reported (\(anyPointer(object)).\(keyPath))")
//        }
        guard let impl = object as? NWTCPConnection, (impl == self.impl) else {
            log.warning("Discard KVO change from old socket")
            return
        }
        guard let keyPath = keyPath else {
            return
        }
        switch keyPath {
        case #keyPath(NWTCPConnection.state):
            if let resolvedEndpoint = impl.remoteAddress {
                log.debug("Socket state is \(impl.state) (endpoint: \(impl.endpoint.maskedDescription) -> \(resolvedEndpoint.maskedDescription))")
            } else {
                log.debug("Socket state is \(impl.state) (endpoint: \(impl.endpoint.maskedDescription) -> in progress)")
            }
            
            switch impl.state {
            case .connected:
                guard !isActive else {
                    return
                }
                isActive = true
                delegate?.socketDidBecomeActive(self)
                
            case .cancelled:
                isShutdown = true
                delegate?.socket(self, didShutdownWithFailure: false)
                
            case .disconnected:
                isShutdown = true
                delegate?.socket(self, didShutdownWithFailure: true)
                
            default:
                break
            }
            
        case #keyPath(NWTCPConnection.hasBetterPath):
            guard impl.hasBetterPath else {
                break
            }
            log.debug("Socket has a better path")
            delegate?.socketHasBetterPath(self)
            
        default:
            break
        }
    }
}

class NETCPLink: LinkInterface {
    private let impl: NWTCPConnection
    
    private let maxPacketSize: Int
    
    init(impl: NWTCPConnection, mtu: Int, maxPacketSize: Int? = nil) {
        self.impl = impl
        self.mtu = mtu
        self.maxPacketSize = maxPacketSize ?? (512 * 1024)
    }

    // MARK: LinkInterface
    
    let isReliable: Bool = true

    var remoteAddress: String? {
        return (impl.remoteAddress as? NWHostEndpoint)?.hostname
    }
    
    let mtu: Int
    
    var packetBufferSize: Int {
        return maxPacketSize
    }
    
    let negotiationTimeout: TimeInterval = 10.0
    
    let hardResetTimeout: TimeInterval = 5.0
    
    func setReadHandler(queue: DispatchQueue, _ handler: @escaping ([Data]?, Error?) -> Void) {
        loopReadPackets(queue, Data(), handler)
    }
    
    private func loopReadPackets(_ queue: DispatchQueue, _ buffer: Data, _ handler: @escaping ([Data]?, Error?) -> Void) {

        // WARNING: runs in Network.framework queue
        impl.readMinimumLength(2, maximumLength: packetBufferSize) { [weak self] (data, error) in
            guard let _ = self else {
                return
            }
            queue.sync {
                guard (error == nil), let data = data else {
                    handler(nil, error)
                    return
                }

                var newBuffer = buffer
                newBuffer.append(contentsOf: data)
                let (until, packets) = PacketStream.packets(from: newBuffer)
                newBuffer = newBuffer.subdata(in: until..<newBuffer.count)
                self?.loopReadPackets(queue, newBuffer, handler)

                handler(packets, nil)
            }
        }
    }

    func writePacket(_ packet: Data, completionHandler: ((Error?) -> Void)?) {
        let stream = PacketStream.stream(from: packet)
        impl.write(stream) { (error) in
            completionHandler?(error)
        }
    }
    
    func writePackets(_ packets: [Data], completionHandler: ((Error?) -> Void)?) {
        let stream = PacketStream.stream(from: packets)
        impl.write(stream) { (error) in
            completionHandler?(error)
        }
    }
}

extension NETCPSocket {
    override var description: String {
        guard let hostEndpoint = impl.endpoint as? NWHostEndpoint else {
            return impl.endpoint.maskedDescription
        }
        return "\(hostEndpoint.hostname.maskedDescription):\(hostEndpoint.port)"
    }
}
