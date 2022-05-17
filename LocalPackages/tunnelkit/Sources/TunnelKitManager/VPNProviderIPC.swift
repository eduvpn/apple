//
//  VPNProviderIPC.swift
//  TunnelKit
//
//  Created by Davide De Rosa on 8/25/21.
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

/// Common IPC functions supported by interactive VPN providers.
public protocol VPNProviderIPC {

    /**
     Request a debug log from the VPN.

     - Parameter fallback: The block resolving to a fallback `String` if no debug log is available.
     - Parameter completionHandler: The completion handler with the debug log.
     */
    func requestDebugLog(fallback: (() -> String)?, completionHandler: @escaping (String) -> Void)

    /**
     Requests the current received/sent bytes count from the VPN.

     - Parameter completionHandler: The completion handler with an optional received/sent bytes count.
     */
    func requestBytesCount(completionHandler: @escaping ((UInt, UInt)?) -> Void)

    /**
     Requests the server configuration from the VPN.

     - Parameter completionHandler: The completion handler with an optional configuration object.
     */
    func requestServerConfiguration(completionHandler: @escaping (Any?) -> Void)
}
