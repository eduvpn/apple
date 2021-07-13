//
//  MenuCommandResponding.swift
//  EduVPN

//  Protocol representing the commands in the 'Server' app menu

import Cocoa

protocol MenuCommandResponding {
    func canGoNextServer() -> Bool
    func goNextServer()

    func canGoPreviousServer() -> Bool
    func goPreviousServer()

    func actionMenuItemTitle() -> String
    func canPerformActionOnServer() -> Bool
    func performActionOnServer()

    func canDeleteServer() -> Bool
    func deleteServer()

    func canToggleVPN() -> Bool
    func toggleVPN()

    func canActivateSelectProfilePopup() -> Bool
    func activateSelectProfilePopup()

    func canGoBackToServerList() -> Bool
    func goBackToServerList()
}

extension MenuCommandResponding {
    func canGoNextServer() -> Bool { return false }
    func goNextServer() { }

    func canGoPreviousServer() -> Bool { return false }
    func goPreviousServer() { }

    func actionMenuItemTitle() -> String { return "Select" }
    func canPerformActionOnServer() -> Bool { return false }
    func performActionOnServer() { }

    func canDeleteServer() -> Bool { return false }
    func deleteServer() { }

    func canToggleVPN() -> Bool { return false }
    func toggleVPN() { }

    func canActivateSelectProfilePopup() -> Bool { return false }
    func activateSelectProfilePopup() { }

    func canGoBackToServerList() -> Bool { return false }
    func goBackToServerList() { }
}
