//
//  VPNConnectionViewController.swift
//  eduVPN
//
//  Created by Johan Kool on 28/06/2017.
//  Copyright © 2017-2019 Commons Conservancy.
//

import os.log
import Cocoa
import NetworkExtension
import TunnelKit
import PromiseKit

private let intervalFormatter: DateComponentsFormatter = {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.hour, .minute, .second]
    formatter.unitsStyle = DateComponentsFormatter.UnitsStyle.abbreviated
    return formatter
}()

enum LogFileError: Error {
    case pathCreationFailed
}

class VPNConnectionViewController: NSViewController {
    
    weak var delegate: VPNConnectionViewControllerDelegate?
    var profile: Profile!
    var providerManagerCoordinator: TunnelProviderManagerCoordinator!
    
    // MARK: - Profile
    
    @IBOutlet weak var providerImage: NSImageView!
    @IBOutlet weak var profileLabel: NSTextField!
    @IBOutlet weak var providerInfoStackView: NSView!
    
    private func displayProfile() {
        profileLabel.stringValue = [profile.profileId, profile.displayString]
            .map { $0 ?? "" }
            .joined(separator: "\n")
        
        if let logo = profile.api?.instance?.logos?.localizedValue, let logoUri = URL(string: logo) {
            updateImage(with: logoUri)
            providerInfoStackView.isHidden = false
        } else {
            cancelImageDownload()
            providerImage.image = nil
            providerInfoStackView.isHidden = true
        }
    }
    
    var status = NEVPNStatus.invalid {
        didSet {
            switch status {
            case .connected:
                statusImage.image = NSImage(named: "connected")
            case .connecting, .disconnecting, .reasserting:
                statusImage.image = NSImage(named: "connecting")
            case .disconnected, .invalid:
                statusImage.image = NSImage(named: "disconnected")
            @unknown default:
                fatalError()
            }
            
            toggleSpinner()
            toggleBackButton()
        }
    }
    
    // MARK: - Status
    
    @IBOutlet weak var statusImage: NSImageView!
    @IBOutlet var buttonConnection: NSButton!
    @IBOutlet var spinner: NSProgressIndicator!
    
    private func subscribeForStatusChanges() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(VPNStatusDidChange(notification:)),
                                               name: .NEVPNStatusDidChange,
                                               object: nil)
    }
    
    private func unsubscribeFromStatusChanges() {
        NotificationCenter.default.removeObserver(self,
                                                  name: .NEVPNStatusDidChange,
                                                  object: nil)
    }
    
    @objc private func VPNStatusDidChange(notification: NSNotification) {
        guard let status = providerManagerCoordinator.currentManager?.connection.status else {
            os_log("VPNStatusDidChange", log: Log.general, type: .debug)
            return
        }
        
        os_log("VPNStatusDidChange: %{public}@", log: Log.general, type: .debug, status.stringRepresentation)
        
        self.status = status
        updateButton()
    }
    
    func updateButton() {
        switch status {
            
        case .connected, .connecting, .disconnecting, .reasserting:
            if profile.isActiveConfig {
                buttonConnection.title = NSLocalizedString("Disconnect", comment: "")
            } else {
                buttonConnection.title = NSLocalizedString("Disconnect existing profile and reconfigure", comment: "")
            }
            
        case .disconnected, .invalid:
            buttonConnection.title = NSLocalizedString("Connect", comment: "")
            
        @unknown default:
            fatalError()
        }
    }
    
    private func statusUpdated() {
        switch status {
            
        case .invalid, .disconnected:
            _ = providerManagerCoordinator.configure(profile: profile).then {
                return self.providerManagerCoordinator.connect()
            }
            
        case .connected, .connecting:
            _ = providerManagerCoordinator.disconnect()
            
        default:
            break
        }
        
        updateButton()
        status = self.providerManagerCoordinator.currentManager?.connection.status ?? .invalid
    }
    
    @IBAction func connectionClicked(_ sender: Any) {
        if status == .invalid {
            providerManagerCoordinator.reloadCurrentManager { [weak self] _ in self?.statusUpdated() }
        } else {
            statusUpdated()
        }
    }
    
    private func toggleSpinner() {
        switch status {
        case .connecting, .disconnecting:
            spinner.startAnimation(nil)
        default:
            spinner.stopAnimation(nil)
        }
    }
    
    // MARK: - Connection info
    
    @IBOutlet var durationLabel: NSTextField!
    @IBOutlet var outBytesLabel: NSTextField!
    @IBOutlet var inBytesLabel: NSTextField!
    @IBOutlet var ipv4AddressField: NSTextField!
    @IBOutlet var ipv6AddressField: NSTextField!
    
    private var connectionInfoUpdateTimer: Timer?
    
    private func scheduleConnectionInfoUpdates() {
        connectionInfoUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { [weak self] (_) in
            self?.updateConnectionInfo()
            try? self?.updateLog()
        })
    }
    
    private func stopConnectionInfoUpdates() {
        connectionInfoUpdateTimer?.invalidate()
        connectionInfoUpdateTimer = nil
    }
    
    private lazy var decoder = JSONDecoder()
    
    func updateConnectionInfo() {
        guard
            let vpn = providerManagerCoordinator.currentManager?.connection as? NETunnelProviderSession,
            profile.isActiveConfig
            else { return }
        
        // IP
        
        try? vpn.sendProviderMessage(OpenVPNTunnelProvider.Message.serverConfiguration.data) { [weak self] data in
            guard let data = data, let serverConfiguration = try? self?.decoder.decode(ServerConfiguration.self, from: data) else {
                self?.ipv4AddressField.stringValue = ""
                self?.ipv6AddressField.stringValue = ""
                return
            }
            
            self?.ipv4AddressField.stringValue = serverConfiguration.ipv4?.address ?? ""
            self?.ipv6AddressField.stringValue = serverConfiguration.ipv6?.address ?? ""
        }
        
        // Interval
        
        let intervalString = vpn.connectedDate.flatMap {
            intervalFormatter.string(from: Date().timeIntervalSinceReferenceDate - $0.timeIntervalSinceReferenceDate)
        }
        
        durationLabel.stringValue = intervalString ?? ""
        
        // Bytes
        
        try? vpn.sendProviderMessage(OpenVPNTunnelProvider.Message.dataCount.data) { [weak self] data in
            let dataCount = data?.withUnsafeBytes { pointer -> (UInt64, UInt64) in
                pointer.load(as: (UInt64, UInt64).self)
            }
            
            self?.inBytesLabel.stringValue = dataCount?.0.bytesText ?? ""
            self?.outBytesLabel.stringValue = dataCount?.1.bytesText ?? ""
        }
    }
    
    // MARK: - Back
    
    @IBOutlet var backButton: NSButton!
    
    private func toggleBackButton() {
        backButton.isHidden = status != .disconnected
    }
    
    @IBAction func goBack(_ sender: Any) {
        assert(status == .disconnected)
        mainWindowController?.popToRoot()
    }
    
    // MARK: - Log
    
    @IBOutlet weak var logTextView: NSTextField!

    private func connectionLogPathDir() throws -> URL {
        guard let logDirPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { throw LogFileError.pathCreationFailed }
        return logDirPath.appendingPathComponent("tmp")
    }

    private func connectionLogPath() throws -> URL {
        return try connectionLogPathDir().appendingPathComponent("connection.log")
    }
    
    private func updateLog() throws {
        try FileManager.default.createDirectory(at: connectionLogPathDir(), withIntermediateDirectories: true)
        try FileManager.default.createFile(atPath: connectionLogPath().path, contents: nil)
        providerManagerCoordinator.loadLog { [weak self] in self?.saveLog($0) }
    }
    
    private func saveLog(_ log: String) {
        guard let logData = log.data(using: .utf8) else { return }
        do {
            let fileHandle = try FileHandle(forUpdating: connectionLogPath())
            fileHandle.seekToEndOfFile()
            fileHandle.write(logData)
        } catch let error {
            os_log("Couldn't save log error: %{public}@", log: Log.general, type: .error, "\(error)")
        }
    }
    
    @IBAction func viewLog(_ sender: Any) {
        if let connectionLogPath = try? connectionLogPath() {
            os_log("Log file: %{public}@", log: Log.general, type: .info, "\(connectionLogPath)")
            NSWorkspace.shared.open(connectionLogPath)
        }
    }
    
    // MARK: - Other
    
    @IBOutlet var statisticsBox: NSBox!
    @IBOutlet var notificationsBox: NSBox!
    @IBOutlet var notificationsField: NSTextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        notificationsField.stringValue = ""
        notificationsBox.isHidden = true
        
        displayProfile()
        providerManagerCoordinator.reloadCurrentManager { _ in
            self.updateButton()
            self.status = self.providerManagerCoordinator.currentManager?.connection.status ?? .invalid
        }
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        subscribeForStatusChanges()
        scheduleConnectionInfoUpdates()
        
        if let concreteDelegate = delegate {
            _ = firstly { () -> Promise<SystemMessages> in
                return concreteDelegate.systemMessages(for: profile)
            }.then({ [weak self] (systemMessages) -> Guarantee<Void> in
                self?.notificationsField.stringValue = systemMessages.displayString
                self?.notificationsBox.isHidden = systemMessages.displayString.isEmpty
                return Guarantee<Void>()
            })
        }
    }
    
    override func viewDidDisappear() {
        super.viewDidDisappear()
        unsubscribeFromStatusChanges()
        stopConnectionInfoUpdates()
    }
    
}

fileprivate extension UInt64 {
    
    var bytesText: String {
        return ByteCountFormatter.string(fromByteCount: Int64(self), countStyle: .binary)
    }
}
