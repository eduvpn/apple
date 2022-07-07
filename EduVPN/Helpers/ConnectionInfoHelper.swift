//
//  ConnectionInfoHelper.swift
//  EduVPN
//

import Foundation
import PromiseKit

class ConnectionInfoHelper {

    struct ConnectionInfo {
        let duration: String
        let profileName: String?
        let vpnProtocol: String?
        let dataTransferred: String
        let addresses: String
    }

    private var networkAddresses: [String] = []
    private var transferredByteCount: TransferredByteCount?

    private let connectionService: ConnectionServiceProtocol
    private let handler: (ConnectionInfo) -> Void
    private var localizedProfileName: String?
    private var vpnProtocol: String?

    private var timer: Timer? {
        didSet(oldValue) {
            oldValue?.invalidate()
        }
    }

    init(connectionService: ConnectionServiceProtocol,
         profileName: LanguageMappedString?,
         handler: @escaping (ConnectionInfo) -> Void) {
        self.connectionService = connectionService
        self.handler = handler
        self.localizedProfileName = profileName?.stringForCurrentLanguage()
        self.vpnProtocol = connectionService.vpnProtocol?.rawValue
    }

    deinit {
        self.timer = nil // invalidate
    }

    func startUpdating() {
        self.update()

        firstly {
            self.connectionService.getNetworkAddresses()
        }.then { networkAddresses in
            self.connectionService.getTransferredByteCount()
                .map { (networkAddresses, $0) }
        }.done { (networkAddresses, transferredByteCount) in
            self.networkAddresses = networkAddresses
            self.transferredByteCount = transferredByteCount
            self.update()
        }

        let timer = Timer(timeInterval: 1 /*second*/, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            guard self.connectionService.connectionStatus == .connected else {
                self.update()
                return
            }
            firstly {
                self.connectionService.getTransferredByteCount()
            }.done { transferredByteCount in
                self.transferredByteCount = transferredByteCount
                self.update()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func refreshNetworkAddress() {
        firstly {
            self.connectionService.getNetworkAddresses()
        }.done { networkAddresses in
            self.networkAddresses = networkAddresses
            self.update()
        }
    }
}

private extension ConnectionInfoHelper {
    static let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    static let byteCountFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter
    }()

    private var connectedDuration: String? {
        guard let connectedDate = connectionService.connectedDate else { return nil }
        return Self.durationFormatter.string(from: connectedDate, to: Date())
    }

    private var downloaded: String? {
        guard let transferredByteCount = transferredByteCount else { return nil }
        return Self.byteCountFormatter.string(fromByteCount: Int64(transferredByteCount.inbound))
    }

    private var uploaded: String? {
        guard let transferredByteCount = transferredByteCount else { return nil }
        return Self.byteCountFormatter.string(fromByteCount: Int64(transferredByteCount.outbound))
    }

    private func update() {
        let dataTransferredString = String(
            format: NSLocalizedString(
                "Downloaded: %@\nUploaded: %@", comment: "Connection Info bytes transferred"),
            downloaded ??
                NSLocalizedString("Unknown", comment: "Connection Info bytes transferred"),
            uploaded ??
                NSLocalizedString("Unknown", comment: "Connection Info bytes transferred"))
        let networkAddressString: String = networkAddresses.joined(separator: "\n")
        self.handler(ConnectionInfo(duration: connectedDuration ??
                                        NSLocalizedString(
                                            "Unknown",
                                            comment: "Connection Info duration"),
                                    profileName: localizedProfileName,
                                    vpnProtocol: vpnProtocol,
                                    dataTransferred: dataTransferredString,
                                    addresses: networkAddressString))
    }
}
