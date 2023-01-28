//
//  LogViewHelpViewController.swift
//  EduVPN
//
//  Created by Roopesh Chander on 27/01/23.
//  Copyright © 2023 SURFNet. All rights reserved.
//

import Foundation
import AppKit

class LogViewHelpViewController: ViewController, ParametrizedViewController {

    struct Parameters {
        let environment: Environment
    }

    private var parameters: Parameters!

    @IBOutlet weak var subsystemLabel: NSTextField!
    @IBOutlet weak var logShowCommandLabel: NSTextField!
    @IBOutlet weak var logStreamCommandLabel: NSTextField!

    var subsystem: String = ""
    var logShowCommand: String = ""
    var logStreamCommand: String = ""

    func initializeParameters(_ parameters: Parameters) {
        guard self.parameters == nil else {
            fatalError("Can't initialize parameters twice")
        }
        self.parameters = parameters
    }

    override func viewDidLoad() {
        let appId = Bundle.main.bundleIdentifier ?? Config.shared.clientId

        self.subsystem = appId
        self.logShowCommand = "log show --info --predicate 'subsystem == \"\(appId)\"'"
        self.logStreamCommand = "log stream --info --predicate 'subsystem == \"\(appId)\"'"

        self.subsystemLabel.text = self.subsystem
        self.logShowCommandLabel.text = self.logShowCommand
        self.logStreamCommandLabel.text = self.logStreamCommand
    }

    @IBAction func subsystemCopyClicked(_ sender: Any) {
        setClipboard(text: self.subsystem)
    }

    @IBAction func logShowCommandCopyClicked(_ sender: Any) {
        setClipboard(text: self.logShowCommand)
    }

    @IBAction func logStreamCommandCopyClicked(_ sender: Any) {
        setClipboard(text: self.logStreamCommand)
    }

    @IBAction func doneClicked(_ sender: Any) {
        self.presentingViewController?.dismiss(self)
    }

    private func setClipboard(text: String) {
        let pasteBoard = NSPasteboard.general
        pasteBoard.clearContents()
        pasteBoard.writeObjects([text as NSString])
    }
}
