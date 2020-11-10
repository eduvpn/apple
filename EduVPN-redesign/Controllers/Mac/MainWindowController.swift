//
//  MainWindowController.swift
//  EduVPN
//

// The window controller is used to enable frame auto saving

import AppKit

class MainWindowController: NSWindowController {
    override func windowDidLoad() {
        super.windowDidLoad()
        self.windowFrameAutosaveName = "Main"
        self.window?.title = Config.shared.appName
    }
}
