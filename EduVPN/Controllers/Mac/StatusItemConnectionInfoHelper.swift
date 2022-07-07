//
//  StatusItemConnectionInfoHelper.swift
//  EduVPN
//

import AppKit
import PromiseKit

class StatusItemConnectionInfoHelper {
    private let connectionService: ConnectionServiceProtocol
    private let handler: (String) -> Void

    private var connectedDate: Date?
    private var transferredByteCount: TransferredByteCount?

    private var timer: Timer? {
        didSet(oldValue) {
            oldValue?.invalidate()
        }
    }

    init(connectionService: ConnectionServiceProtocol, handler: @escaping (String) -> Void) {
        self.connectionService = connectionService
        self.handler = handler
    }

    deinit {
        self.timer = nil // invalidate
    }

    func startUpdating() {
        firstly {
            self.connectionService.getConnectedDate()
        }.then { connectedDate in
            self.connectionService.getTransferredByteCount()
                .map { (connectedDate, $0) }
        }.done { connectedDate, transferredByteCount in
            self.connectedDate = connectedDate
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
                self.connectionService.getConnectedDate()
            }.then { connectedDate in
                self.connectionService.getTransferredByteCount()
                    .map { (connectedDate, $0) }
            }.done { connectedDate, transferredByteCount in
                self.connectedDate = connectedDate
                self.transferredByteCount = transferredByteCount
                self.update()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
}

private extension StatusItemConnectionInfoHelper {
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
        guard let connectedDate = self.connectedDate else { return nil }
        return Self.durationFormatter.string(from: connectedDate, to: Date())
    }

    private func update() {
        var connectionInfoString = connectedDuration ?? ""
        if let transferredByteCount = transferredByteCount {
            let downloaded = Self.byteCountFormatter.string(fromByteCount: Int64(transferredByteCount.inbound))
            let uploaded = Self.byteCountFormatter.string(fromByteCount: Int64(transferredByteCount.outbound))
            connectionInfoString.append(" • Down: \(downloaded) • Up: \(uploaded)")
        }
        self.handler(connectionInfoString)
    }
}
