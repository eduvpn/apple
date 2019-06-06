//
//  VPNConnectionViewController.swift
//  eduVPN
//
//  Created by Jeroen Leenarts on 24-09-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

import UIKit
import os.log
import NetworkExtension
import TunnelKit
import PromiseKit

private let intervalFormatter: DateComponentsFormatter = {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.hour, .minute, .second]
    formatter.unitsStyle = DateComponentsFormatter.UnitsStyle.abbreviated
    return formatter
}()

class VPNConnectionViewController: UIViewController {
    
    weak var delegate: VPNConnectionViewControllerDelegate?

    @IBOutlet var buttonConnection: UIButton!

    @IBOutlet weak var notificationLabel: UILabel!

    @IBOutlet var durationLabel: UILabel!

    @IBOutlet var outBytesLabel: UILabel!

    @IBOutlet var inBytesLabel: UILabel!

    @IBOutlet weak var logTextView: UITextView!

    @IBOutlet weak var providerInfoStackView: UIStackView!

    var providerManagerCoordinator: TunnelProviderManagerCoordinator!

    private var connectionInfoUpdateTimer: Timer?

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

    var profile: Profile!

    @IBOutlet weak var statusImage: UIImageView!

    @IBOutlet weak var providerImage: UIImageView!
    @IBOutlet weak var profileNameLabel: UILabel!
    @IBOutlet weak var instanceNameLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()

        profileNameLabel.text = profile.profileId
        instanceNameLabel.text = profile.displayString
        if let logo = profile.api?.instance?.logos?.localizedValue, let logoUri = URL(string: logo) {
            providerImage.af_setImage(withURL: logoUri)
            providerInfoStackView.isHidden = false
        } else if let providerTypeString = profile.api?.instance?.providerType, providerTypeString == ProviderType.other.rawValue {
            providerImage.af_cancelImageRequest()
            providerImage.image = nil
            providerInfoStackView.isHidden = true
        } else {
            providerImage.af_cancelImageRequest()
            providerImage.image = nil
            providerInfoStackView.isHidden = true
        }

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(VPNStatusDidChange(notification:)),
                                               name: .NEVPNStatusDidChange,
                                               object: nil)

        providerManagerCoordinator.reloadCurrentManager { _ in
            self.updateButton()
            self.status = self.providerManagerCoordinator.currentManager?.connection.status ?? .invalid
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { [weak self] _ in
            self?.updateConnectionInfo()
        })
        if let concreteDelegate = delegate {
            _ = firstly { () -> Promise<SystemMessages> in
                return concreteDelegate.systemMessages(for: profile)
            }.then({ [weak self] (systemMessages) -> Guarantee<Void> in
                self?.notificationLabel.text = systemMessages.displayString
                return Guarantee<Void>()
            })
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        connectionInfoUpdateTimer?.invalidate()
        connectionInfoUpdateTimer = nil
    }

    @IBAction func closeClicked(_ sender: Any) {
        self.presentingViewController?.dismiss(animated: true, completion: nil)
    }

    @IBAction func displayLogClicked(_ sender: Any) {
        self.providerManagerCoordinator.loadLog { [weak self] log in
            self?.logTextView.text = log
        }
    }

    @IBAction func connectionClicked(_ sender: Any) {
        let block = {
            switch self.status {
            case .invalid, .disconnected:
                _ = self.providerManagerCoordinator.configure(profile: self.profile).then {
                    return self.providerManagerCoordinator.connect()
                }
            case .connected, .connecting:
                _ = self.providerManagerCoordinator.disconnect()
            default:
                break
            }

            self.updateButton()
            self.status = self.providerManagerCoordinator.currentManager?.connection.status ?? .invalid
        }

        if status == .invalid {
            providerManagerCoordinator.reloadCurrentManager { _ in block() }
        } else {
            block()
        }
    }

    func updateButton() {
        switch status {
        case .connected, .connecting, .disconnecting, .reasserting:
            if profile.isActiveConfig {
                buttonConnection.setTitle(NSLocalizedString("Disconnect", comment: ""), for: .normal)
            } else {
                buttonConnection.setTitle(NSLocalizedString("Disconnect existing profile and reconfigure", comment: ""), for: .normal)
            }

        case .disconnected, .invalid:
            buttonConnection.setTitle(NSLocalizedString("Connect", comment: ""), for: .normal)
        @unknown default:
            fatalError()
        }
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

    func updateConnectionInfo() {
        guard let vpn = providerManagerCoordinator.currentManager?.connection as? NETunnelProviderSession else {
            return
        }
        guard profile.isActiveConfig else {
            return
        }
        let intervalString = vpn.connectedDate.flatMap {
            intervalFormatter.string(from: Date().timeIntervalSinceReferenceDate - $0.timeIntervalSinceReferenceDate)
        }

        durationLabel.text = intervalString

        try? vpn.sendProviderMessage(TunnelKitProvider.Message.dataCount.data) { [weak self] data in
            let dataCount = data?.withUnsafeBytes{ pointer -> (UInt64, UInt64) in
                pointer.load(as: (UInt64, UInt64).self)
            }
            
            if let inByteCount = dataCount?.0 {
                self?.inBytesLabel.text = ByteCountFormatter.string(fromByteCount: Int64(inByteCount), countStyle: .binary )
            } else {
                self?.inBytesLabel.text = nil
            }
            if let outByteCount = dataCount?.1 {
                self?.outBytesLabel.text = ByteCountFormatter.string(fromByteCount: Int64(outByteCount), countStyle: .binary )
            } else {
                self?.outBytesLabel.text = nil
            }
        }
    }
}

extension NEVPNStatus {
    var stringRepresentation: String {
        switch self {
        case .connected:
            return "Connected"
        case .connecting:
            return "Connecting"
        case .disconnected:
            return "Disconnected"
        case .disconnecting:
            return "Disconnecting"
        case .invalid:
            return "Invalid"
        case .reasserting:
            return "Reasserting"
        @unknown default:
            fatalError()
        }
    }
}
