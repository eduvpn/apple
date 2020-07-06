//
//  ConnectionViewController.swift
//  EduVPN
//
//  Created by Johan Kool on 28/05/2020.
//

import Foundation

protocol ConnectionViewControllerDelegate: class {
    func connectionViewControllerClosed(_ controller: ConnectionViewController)
}

class ConnectionViewController: ViewController {
    
    var viewModel: ConnectionViewModel!
    weak var delegate: ConnectionViewControllerDelegate?

    @IBOutlet private var backButton: Button!
    
    @IBOutlet private var iconImageView: ImageView!
    @IBOutlet private var nameLabel: Label!
    @IBOutlet private var supportView: StackView!
    @IBOutlet private var supportLabel: Label!
    @IBOutlet private var supportValueLabel: Label!
    @IBOutlet private var connectionImageView: ImageView!
    @IBOutlet private var connectionStatusLabel: Label!
    @IBOutlet private var connectionStatusDetailLabel: Label!
    
    @IBOutlet private var mainSwitch: Switch!
    @IBOutlet private var renewSessionButton: Button!
    @IBOutlet private var profilesView: StackView!
    
    @IBOutlet private var connectionInfoLabel: Label!
    @IBOutlet private var connectionInfoToggleButton: Button!
    @IBOutlet private var connectionInfoContentView: StackView!
    @IBOutlet private var durationLabel: Label!
    @IBOutlet private var durationValueLabel: Label!
    @IBOutlet private var downloadedLabel: Label!
    @IBOutlet private var downloadedValueLabel: Label!
    @IBOutlet private var uploadedLabel: Label!
    @IBOutlet private var uploadedValueLabel: Label!
    @IBOutlet private var ipv4AddressLabel: Label!
    @IBOutlet private var ipv4AddressValueLabel: Label!
    @IBOutlet private var ipv6AddressLabel: Label!
    @IBOutlet private var ipv6AddressValueLabel: Label!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupView()
        setupViewModel()
    }
    
    private func setupView() {
        // Here you can apply styling, fonts, colors etc.
    }
    
    private func setupViewModel() {
        // Here you connect the UI with the view model
        viewModel.updateConnectionHandler = { [weak self] connectionState in
            guard let self = self else { return }
            self.backButton.isHidden = !connectionState.canClose
            self.iconImageView.image = connectionState.icon
            self.nameLabel.text = connectionState.name
            self.supportView.isHidden = connectionState.support == nil
            self.supportValueLabel.text = connectionState.support
            self.connectionImageView.image = connectionState.connectionImage
            self.connectionStatusLabel.text = connectionState.connectionStatus
            self.connectionStatusDetailLabel.text = connectionState.connectionStatusDetail
            self.mainSwitch.isHidden = connectionState.hasProfilesSection
            self.mainSwitch.isOn = connectionState.profiles.first?.enabled ?? false
            self.profilesView.isHidden = !connectionState.hasProfilesSection
            if connectionState.hasProfilesSection {
                // Not entirely happy with this approach, but want to avoid using a table view
                // Could optimize by reusing views
                var doomedViews = self.profilesView.arrangedSubviews
                doomedViews.removeFirst()
                for doomedView in doomedViews {
                    self.profilesView.removeArrangedSubview(doomedView)
                    doomedView.removeFromSuperview()
                }
                
                for (index, profile) in connectionState.profiles.enumerated() {
                    let label = Label()
                    label.text = profile.name
                    let toggle = Switch()
                    toggle.isOn = profile.enabled
                    toggle.addTarget(self, action: #selector(self.toggleSwitch(_:)), for: .touchUpInside)
                    toggle.tag = index
                    let profileView = StackView(arrangedSubviews: [label, toggle])
                    profileView.distribution = .equalSpacing
                    self.profilesView.addArrangedSubview(profileView)
                }
            }
            self.renewSessionButton.isHidden = !connectionState.showsRenewSessionButton
            self.connectionInfoContentView.isHidden = !connectionState.showsConnectionInfo
        }
        
        viewModel.updateConnectionInfoHandler = { [weak self] connectionInfoState in
            guard let self = self else { return }
            self.durationValueLabel.text = connectionInfoState.duration
            self.downloadedValueLabel.text = connectionInfoState.download
            self.uploadedValueLabel.text = connectionInfoState.upload
            self.ipv4AddressValueLabel.text = connectionInfoState.ipv4Address
            self.ipv6AddressValueLabel.text = connectionInfoState.ipv6Address
        }
    }
    
    @IBAction func back(_ sender: Any) {
        delegate?.connectionViewControllerClosed(self)
    }
    
    @IBAction func toggleMainSwitch(_ sender: Any) {
        viewModel.toggleProfile(0, enabled: mainSwitch.isOn)
    }
    
    @IBAction func toggleSwitch(_ sender: Any) {
        guard let tag = (sender as? Switch)?.tag, let enabled = (sender as? Switch)?.isOn else { return }
        viewModel.toggleProfile(tag, enabled: enabled)
    }
    
    @IBAction func renewSession(_ sender: Any) {
        viewModel.renewSession()
    }
    
    @IBAction func toggleConnectionInfo(_ sender: Any) {
        viewModel.toggleConnectionInfo(visible: connectionInfoToggleButton.isSelected)
    }
}
