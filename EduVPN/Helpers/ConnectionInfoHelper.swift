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
        let dataTransferred: String
        let addresses: String
    }

    private var networkAddress: NetworkAddress? {
        didSet {
            self.update()
        }
    }

    private var transferredByteCount: TransferredByteCount? {
        didSet {
            self.update()
        }
    }

    private let connectionService: ConnectionServiceProtocol
    private let handler: (ConnectionInfo) -> Void
    private var localizedProfileName: String?

    private var timer: Timer? {
        didSet(oldValue) {
            oldValue?.invalidate()
        }
    }

    init(connectionService: ConnectionServiceProtocol, profileName: LanguageMappedString?, handler: @escaping (ConnectionInfo) -> Void) {
        self.connectionService = connectionService
        self.handler = handler
        self.localizedProfileName = profileName?.stringForCurrentLanguage()
    }

    deinit {
        self.timer = nil // invalidate
    }

    func startUpdating() {
        self.update()

        firstly {
            self.connectionService.getNetworkAddress()
        }.map { networkAddress in
            self.networkAddress = networkAddress
        }.then {
            self.connectionService.getTransferredByteCount()
        }.done { transferredByteCount in
            self.transferredByteCount = transferredByteCount
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
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func refreshNetworkAddress() {
        firstly {
            self.connectionService.getNetworkAddress()
        }.done { networkAddress in
            self.networkAddress = networkAddress
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
        guard let networkAddress = networkAddress else { return }
        let dataTransferredString = String(
            format: NSLocalizedString(
                "Downloaded: %@\nUploaded: %@", comment: "Connection Info bytes transferred"),
            downloaded ??
                NSLocalizedString("Unknown", comment: "Connection Info bytes transferred"),
            uploaded ??
                NSLocalizedString("Unknown", comment: "Connection Info bytes transferred"))
        let networkAddressString: String = {
            switch (networkAddress.ipv4, networkAddress.ipv6) {
            case (nil, nil): return NSLocalizedString(
                "No addresses",
                comment: "Connection Info network address")
            case (let ipv4, nil): return ipv4! // swiftlint:this:disable force_unwrapping
            case (nil, let ipv6): return ipv6! // swiftlint:this:disable force_unwrapping
            case (let ipv4, let ipv6): return "\(ipv4!)\n\(ipv6!)" // swiftlint:this:disable force_unwrapping
            }
        }()
        self.handler(ConnectionInfo(duration: connectedDuration ??
                                        NSLocalizedString(
                                            "Unknown",
                                            comment: "Connection Info duration"),
                                    profileName: localizedProfileName,
                                    dataTransferred: dataTransferredString,
                                    addresses: networkAddressString))
    }
}
