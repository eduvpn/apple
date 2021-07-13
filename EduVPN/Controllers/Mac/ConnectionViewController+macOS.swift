//
//  ConnectionViewController+macOS.swift
//  EduVPN

import Cocoa

extension ConnectionViewController: MenuCommandRespondingViewController {
    func canToggleVPN() -> Bool {
        return vpnSwitch.isEnabled
    }

    func toggleVPN() {
        vpnSwitch.isOn = !vpnSwitch.isOn
        vpnSwitchToggled()
    }

    func canGoBackToServerList() -> Bool {
        return canGoBack()
    }

    func goBackToServerList() {
        goBack()
    }
}
