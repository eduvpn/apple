//
//  main.swift
//  TunnelSystemExtension-macOS
//
//  Copyright © 2023 The Commons Conservancy. All rights reserved.
//

import Foundation
import NetworkExtension

autoreleasepool {
    NEProvider.startSystemExtensionMode()
}

dispatchMain()
