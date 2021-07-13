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

    func canActivateSelectProfilePopup() -> Bool {
        return !profileSelectionView.isHidden
    }

    func activateSelectProfilePopup() {
        if !profileSelectionView.isHidden {
            (NSApp.delegate as? AppDelegate)?.showMainWindow(self)
            profileSelectorPopupButton.performClick(self)
        }
    }

    func canGoBackToServerList() -> Bool {
        return canGoBack()
    }

    func goBackToServerList() {
        goBack()
    }
}
