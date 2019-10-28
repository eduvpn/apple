//
//  NSError+App.swift
//  EduVPN-macOS
//
//  Created by Aleksandr Poddubny on 24/05/2019.
//  Copyright © 2019 SURFNet. All rights reserved.
//

import Foundation

extension NSError {
    
    static func withLocalizedDescription(key: String) -> NSError {
        return NSError(domain: Bundle.main.bundleIdentifier!,
                       code: 0,
                       userInfo: [NSLocalizedDescriptionKey: key])
    }
}
