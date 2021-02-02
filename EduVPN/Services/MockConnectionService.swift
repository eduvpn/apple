//
//  MockConnectionService.swift
//  EduVPN
//

import Foundation
import NetworkExtension
import PromiseKit

class MockConnectionService: ConnectionServiceProtocol {

    weak var initializationDelegate: ConnectionServiceInitializationDelegate?
    weak var statusDelegate: ConnectionServiceStatusDelegate?

    private(set) var connectionStatus: NEVPNStatus = .invalid {
        didSet {
            self.statusDelegate?.connectionService(self, connectionStatusChanged: self.connectionStatus)
        }
    }

    private(set) var isInitialized: Bool = false
    private(set) var isVPNEnabled: Bool = false
    private(set) var connectionAttemptId: UUID?
    private(set) var connectedDate: Date?

    init() {
        after(seconds: 1)
            .map {
                self.isInitialized = true
                self.connectionStatus = .disconnected
                self.initializationDelegate?.connectionService(self, initializedWithState: .vpnDisabled)
            }.cauterize()
    }

    func enableVPN(openVPNConfig: [String], connectionAttemptId: UUID,
                   credentials: Credentials?, shouldDisableVPNOnError: Bool) -> Promise<Void> {
        guard isInitialized else {
            fatalError("ConnectionService not initialized yet")
        }
        self.connectionStatus = .connecting
        return after(seconds: 5)
            .map {
                self.isVPNEnabled = true
                self.connectionAttemptId = connectionAttemptId
                self.connectedDate = Date()
                self.connectionStatus = .connected
            }
    }

    func disableVPN() -> Promise<Void> {
        guard isInitialized else {
            fatalError("ConnectionService not initialized yet")
        }
        self.connectionStatus = .disconnecting
        return after(seconds: 1)
            .map {
                self.isVPNEnabled = false
                self.connectionAttemptId = nil
                self.connectedDate = nil
                self.connectionStatus = .disconnected
            }
    }

    func getNetworkAddress() -> Guarantee<NetworkAddress> {
        guard isInitialized else {
            fatalError("ConnectionService not initialized yet")
        }
        return .value(NetworkAddress(ipv4: nil, ipv6: nil))
    }

    func getTransferredByteCount() -> Guarantee<TransferredByteCount> {
        guard isInitialized else {
            fatalError("ConnectionService not initialized yet")
        }
        return .value(TransferredByteCount(inbound: 0, outbound: 0))
    }

    func getConnectionLog() -> Promise<String?> {
        guard isInitialized else {
            fatalError("ConnectionService not initialized yet")
        }
        return .value("Mock log\n----\nEOF\n----\n")
    }
}
