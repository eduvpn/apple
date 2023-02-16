//
//  MainViewController+StatusMenu.swift
//  EduVPN
//

import AppKit
import PromiseKit

extension MainViewController: StatusItemControllerDataSource {
    func currentServer() -> (ConnectionViewModel.ConnectionFlowStatus, ConnectableInstance?) {
        if let connectionVC = self.currentConnectionVC {
            let status = connectionVC.status
            let instance = connectionVC.connectableInstance
            return (status, instance)
        }
        return (.notConnected, nil)
    }

    func addedServersListRows() -> [MainViewModel.Row] {
        viewModel.rows
    }
}

extension MainViewController: StatusItemControllerDelegate {
    func disableVPN() {
        self.currentConnectionVC?.disableVPN()
    }

    func startConnectionFlow(with connectableInstance: ConnectableInstance) {
        firstly { () -> Promise<Void> in
            if let currentConnectionVC = self.currentConnectionVC {
                return currentConnectionVC.disableVPN()
            } else {
                return Promise.value(())
            }
        }.map {
            self.pushConnectionVC(
                connectableInstance: connectableInstance,
                postLoadAction: .beginConnectionFlow(continuationPolicy: .continueWithAnyProfile))
        }.cauterize()
    }
}
