//
//  Testing.swift
//  EduVPN
//
//  Created by Johan Kool on 11/12/2020.
//  Copyright © 2020 SURFNet. All rights reserved.
//

import Foundation

extension ProcessInfo {
    /**
     Used to recognized that UITestings are running and modify the app behavior accordingly
     Set with: XCUIApplication().launchArguments = [ "isUITesting" ]
     */
    var isUITesting: Bool {
        return arguments.contains("isUITesting")
    }
    
    /**
     Used to recognized that UITestings are running and modify the app behavior as if it runs for the first time
     Set with: XCUIApplication().launchArguments = [ "isTakingSnapshots" ]
     */
    var isUITestingFreshInstall: Bool {
        return arguments.contains("isUITestingFreshInstall")
    }
    
    /**
     Used to recognized that UITestings are running and modify the app behavior as if it has a server configured
     Set with: XCUIApplication().launchArguments = [ "isTakingSnapshots" ]
     */
    var isUITestingConfigured: Bool {
        return arguments.contains("isUITestingConfigured")
    }
    
    /**
     Used to recognized that UITestings are taking snapshots and modify the app behavior accordingly
     Set with: XCUIApplication().launchArguments = [ "isTakingSnapshots" ]
     */
    var isTakingSnapshots: Bool {
        return arguments.contains("isTakingSnapshots")
    }
}
