//
//  VPNConnectionViewController.swift
//  eduVPN
//
//  Created by Jeroen Leenarts on 24-09-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

import os.log
import NetworkExtension
import TunnelKit
import PromiseKit
import UIKit

private let intervalFormatter: DateComponentsFormatter = {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.hour, .minute, .second]
    formatter.unitsStyle = DateComponentsFormatter.UnitsStyle.abbreviated
    return formatter
}()

class VPNConnectionViewController: UIViewController {

    weak var delegate: VPNConnectionViewControllerDelegate?
    var profile: Profile!
    var providerManagerCoordinator: TunnelProviderManagerCoordinator!

    private var postponeButtonUpdates = false {
        didSet {
            updateButton()
        }
    }

    // MARK: - Profile

    @IBOutlet weak var providerImage: UIImageView!
    @IBOutlet weak var profileNameLabel: UILabel!
    @IBOutlet weak var buttonDisplayLog: UIButton!
    @IBOutlet weak var instanceNameLabel: UILabel!
    @IBOutlet weak var providerInfoStackView: UIStackView!

    private func displayProfile() {
        profileNameLabel.text = profile.displayString
        instanceNameLabel.text = profile.providerDisplayString

        if let logo = profile.api?.instance?.logos?.localizedValue, let logoUri = URL(string: logo) {
            ImageLoader.loadImage(logoUri, target: providerImage)
            providerInfoStackView.isHidden = false
        } else {
            ImageLoader.cancelLoadImage(target: providerImage)
            providerImage.image = nil
            providerInfoStackView.isHidden = true
        }
    }

    // MARK: - Status

    private var refreshLog: Bool = false

    var status = NEVPNStatus.invalid {
        didSet {
            switch status {
            case .connected:
                statusImage.image = UIImage(named: "connected")
            case .connecting, .disconnecting, .reasserting:
                statusImage.image = UIImage(named: "connecting")
            case .disconnected, .invalid:
                statusImage.image = UIImage(named: "disconnected")
            @unknown default:
                fatalError()
            }
        }
    }

    @IBOutlet weak var statusImage: UIImageView!
    @IBOutlet var buttonConnection: UIButton!

    private func subscribeForStatusChanges() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(VPNStatusDidChange(notification:)),
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

        case .connected:
            if profile.isActiveConfig {
                buttonConnection.setTitle(NSLocalizedString("Disconnect", comment: ""), for: .normal)
            } else {
                buttonConnection.setTitle(NSLocalizedString("Disconnect existing profile and reconfigure", comment: ""), for: .normal)
            }
            buttonConnection.isHidden = false || postponeButtonUpdates
        case .connecting, .disconnecting, .reasserting:
            buttonConnection.setTitle(NSLocalizedString("Disconnect", comment: ""), for: .normal, for: .normal)
            buttonConnection.isHidden = false || postponeButtonUpdates

        case .disconnected, .invalid:
            buttonConnection.setTitle(NSLocalizedString("Connect", comment: ""), for: .normal)
            buttonConnection.isHidden = false || postponeButtonUpdates

        @unknown default:
            fatalError()
        }
    }

    private func statusUpdated() {
        switch status {
        case .invalid, .disconnected:
            _ = connect()
        case .connected, .connecting:
            _ = disconnect()
        default:
            _ = self.providerManagerCoordinator.disconnect()
        }
    }

    private func postStatusUpdatePromise() -> Promise<Void> {
        self.status = self.providerManagerCoordinator.currentManager?.connection.status ?? .invalid
        self.postponeButtonUpdates = false
        return Promise.value(())

    }

    func connect() -> Promise<Void> {
        self.postponeButtonUpdates = true

        return providerManagerCoordinator.configure(profile: profile).then {
            return self.providerManagerCoordinator.connect()
        }.then { return self.postStatusUpdatePromise() }
    }

    func disconnect() -> Promise<Void> {
        self.postponeButtonUpdates = true

        return providerManagerCoordinator.checkOnDemandEnabled().then { onDemandEnabled -> Promise<Void> in
            if let delegate = self.delegate, onDemandEnabled {
                return delegate.confirmDisconnectWhileOnDemandEnabled().then({ disconnect -> Promise<Void> in
                    if disconnect {
                        return self.providerManagerCoordinator.disconnect()
                    } else {
                        return Promise.value(())
                    }
                })
            } else {
                return self.providerManagerCoordinator.disconnect()
            }
        }.then { return self.postStatusUpdatePromise() }
    }

    @IBAction func connectionClicked(_ sender: Any) {
        if status == .invalid {
            providerManagerCoordinator.reloadCurrentManager { [weak self] _ in self?.statusUpdated() }
        } else {
            statusUpdated()
        }
    }

    // MARK: - Connection info

    @IBOutlet var durationLabel: UILabel!
    @IBOutlet var outBytesLabel: UILabel!
    @IBOutlet var inBytesLabel: UILabel!

    private var connectionInfoUpdateTimer: Timer?

    private func scheduleConnectionInfoUpdates() {
        connectionInfoUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { [weak self] (_) in
            self?.updateConnectionInfo()
        })
    }

    private func stopConnectionInfoUpdates() {
        connectionInfoUpdateTimer?.invalidate()
        connectionInfoUpdateTimer = nil
    }

    func updateConnectionInfo() {
        guard
            let vpn = providerManagerCoordinator.currentManager?.connection as? NETunnelProviderSession,
            profile.isActiveConfig
            else { return }

        let intervalString = vpn.connectedDate.flatMap {
            intervalFormatter.string(from: Date().timeIntervalSinceReferenceDate - $0.timeIntervalSinceReferenceDate)
        }

        durationLabel.text = intervalString

        try? vpn.sendProviderMessage(OpenVPNTunnelProvider.Message.dataCount.data) { [weak self] (data) in
            let dataCount = data?.withUnsafeBytes({ (pointer) -> (UInt64, UInt64) in
                pointer.load(as: (UInt64, UInt64).self)
            })

            self?.inBytesLabel.text = dataCount?.0.bytesText
            self?.outBytesLabel.text = dataCount?.1.bytesText
        }

        if refreshLog {
            self.providerManagerCoordinator.loadLog { [weak self] (log) in
                self?.logTextView.text = log
            }
        }
    }

    // MARK: - Back

    @IBAction func closeClicked(_ sender: Any) {
        self.presentingViewController?.dismiss(animated: true, completion: nil)
    }

    // MARK: - Log

    @IBOutlet weak var logTextView: UITextView!

    @IBAction func displayLogClicked(_ sender: Any) {
        refreshLog.toggle()

        buttonDisplayLog.titleLabel?.text = refreshLog ? NSLocalizedString("Stop refreshing log", comment: "") : NSLocalizedString("Display log", comment: "")
    }

    // MARK: - Other

    @IBOutlet weak var notificationLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()

        displayProfile()

        providerManagerCoordinator.reloadCurrentManager { _ in
            self.status = self.providerManagerCoordinator.currentManager?.connection.status ?? .invalid
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        scheduleConnectionInfoUpdates()
        subscribeForStatusChanges()

        if let concreteDelegate = delegate {
            _ = firstly { () -> Promise<SystemMessages> in
                return concreteDelegate.systemMessages(for: profile)
            }.then({ [weak self] (systemMessages) -> Guarantee<Void> in
                self?.notificationLabel.text = systemMessages.displayString
                return Guarantee<Void>()
            })
        }

        if refreshLog {
            self.providerManagerCoordinator.loadLog { [weak self] (log) in
                self?.logTextView.text = log
            }
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopConnectionInfoUpdates()
    }
}

fileprivate extension UInt64 {

    var bytesText: String {
        return ByteCountFormatter.string(fromByteCount: Int64(self), countStyle: .binary)
    }
}
