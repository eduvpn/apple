//
//  FileService.swift
//  EduVPN-macOS
//
//  Created by Aleksandr Poddubny on 24/05/2019.
//  Copyright © 2019 SURFNet. All rights reserved.
//

import Foundation

func applicationSupportDirectoryUrl() -> URL? {
    guard var url = try? FileManager.default.url(for: .applicationSupportDirectory,
                                                 in: .userDomainMask,
                                                 appropriateFor: nil,
                                                 create: true)
        else { return nil }
    
    #if os(macOS)
    url.appendPathComponent(Bundle.main.bundleIdentifier!)
    do {
        try FileManager.default.createDirectory(at: url,
                                                withIntermediateDirectories: true,
                                                attributes: nil)
    } catch {
        return nil
    }
    #endif
    
    return url
}
