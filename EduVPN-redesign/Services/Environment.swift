//
//  Environment.swift
//  eduVPN 2
//
//  Created by Johan Kool on 28/05/2020.
//  Copyright © 2020 SURFNet. All rights reserved.
//

import Foundation

struct Environment {
    let config: Config
    let storyboard: Storyboard
    let mainService: MainServiceType
    let searchService: SearchServiceType
    let settingsService: SettingsServiceType
    let connectionService: ConnectionServiceType
}
