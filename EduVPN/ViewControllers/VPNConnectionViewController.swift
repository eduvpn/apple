//
//  VPNConnectionViewController.swift
//  eduVPN
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

    private var isVPNEnabled = false {
        didSet {
            updateButton()
            updateDismissability()
        }
    }

    private var isVPNBeingConfigured = false {
        didSet {
            updateButton()
            updateDismissability()
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
        updateDisplayLogButtonEnabled()
    }

    func updateButton() {
        let buttonTitle = isVPNEnabled ?
            NSLocalizedString("Disconnect", comment: "") :
            NSLocalizedString("Connect", comment: "")
        buttonConnection.setTitle(buttonTitle, for: .normal)
        buttonConnection.isEnabled = !isVPNBeingConfigured
    }

    func connect() -> Promise<Void> {
        self.postponeButtonUpdates = true
        self.isVPNBeingConfigured = true

        return providerManagerCoordinator.configure(profile: profile)
            .then {
                $0.connect()
            }.map {
                self.isVPNEnabled = self.providerManagerCoordinator.isOnDemandEnabled
            }.ensure {
                self.isVPNBeingConfigured = false
                self.postponeButtonUpdates = false
            }
    }

    func disconnect() -> Promise<Void> {
        self.postponeButtonUpdates = true

        return providerManagerCoordinator.disconnect()
            .map {
                self.isVPNEnabled = self.providerManagerCoordinator.isOnDemandEnabled
            }.ensure {
                self.postponeButtonUpdates = false
            }
    }

    @IBAction func connectionClicked(_ sender: Any) {
        if isVPNEnabled {
            disconnect()
                .cauterize()
        } else {
            connect()
                .cauterize()
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
        if status != .connected {
            durationLabel.text = ""
            inBytesLabel.text = ""
            outBytesLabel.text = ""
            
            return
        }
        
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

    @IBOutlet weak var closeButton: UIBarButtonItem!

    @IBAction func closeClicked(_ sender: Any) {
        self.presentingViewController?.dismiss(animated: true, completion: nil)
    }

    func updateDismissability() {
        let isDismissable = (!isVPNEnabled && !isVPNBeingConfigured)
        closeButton.isEnabled = isDismissable
        if #available(iOS 13, *) {
            isModalInPresentation = !isDismissable
        }
    }

    // MARK: - Log

    @IBOutlet weak var logTextView: UITextView!

    @IBAction func displayLogClicked(_ sender: Any) {
        refreshLog.toggle()

        let buttonTitle = refreshLog ?
            NSLocalizedString("Stop refreshing log", comment: "") :
            NSLocalizedString("Display log", comment: "")
        buttonDisplayLog.setTitle(buttonTitle, for: .normal)
    }

    private func updateDisplayLogButtonEnabled() {
        // Whether we can view the log or not depends on the connection status
        buttonDisplayLog.isEnabled = providerManagerCoordinator.canLoadLog()
    }

    // MARK: - Other

    @IBOutlet weak var notificationLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()

        displayProfile()

        self.buttonConnection.isEnabled = false
        providerManagerCoordinator.getCurrentTunnelProviderManager()
            .map { manager in
                self.isVPNEnabled = self.providerManagerCoordinator.isOnDemandEnabled
                self.status = manager?.connection.status ?? .invalid
                self.buttonConnection.isEnabled = true
            }.cauterize()
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
