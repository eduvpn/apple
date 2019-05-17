//
//  ChooseConnectionTypeViewController.swift
//  eduVPN
//
//  Created by Johan Kool on 06/07/2017.
//  Copyright © 2017-2019 Commons Conservancy.
//

import Cocoa

class ChooseConnectionTypeViewController: NSViewController {

    @IBOutlet var secureInternetButton: NSButton!
    @IBOutlet var instituteAccessButton: NSButton!
    @IBOutlet var closeButton: NSButton!
    @IBOutlet var enterProviderButton: NSButton!
    @IBOutlet var chooseConfigFileButton: NSButton!
    
    var allowClose: Bool = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        closeButton.isHidden = !allowClose
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        secureInternetButton.isEnabled = true
        instituteAccessButton.isEnabled = true
        
        secureInternetButton.isHidden = !ServiceContainer.appConfig.apiDiscoveryEnabled
        instituteAccessButton.isHidden = !ServiceContainer.appConfig.apiDiscoveryEnabled
    }
    
    @IBAction func chooseSecureInternet(_ sender: Any) {
        discoverProviders(connectionType: .secureInternet)
    }
   
    @IBAction func chooseInstituteAccess(_ sender: Any) {
        discoverProviders(connectionType: .instituteAccess)
    }
    
    @IBAction func close(_ sender: Any) {
        mainWindowController?.dismiss()
    }
    
    @IBAction func enterProviderURL(_ sender: Any) {
        guard let window = view.window else {
            return
        }
        let enterProviderURLViewController = storyboard!.instantiateController(withIdentifier: "EnterProviderURL") as! EnterProviderURLViewController
        let panel = NSPanel(contentViewController: enterProviderURLViewController)
        window.beginSheet(panel) { (response) in
            switch response {
            case .OK:
                if let baseURL = enterProviderURLViewController.url {
                    self.addURL(baseURL: baseURL)
                }
            default:
                break
            }
        }
    }
    
    private func addURL(baseURL: URL) {
        let provider = Provider(displayName: baseURL.host ?? "", baseURL: baseURL, logoURL: nil, publicKey: nil, username: nil, connectionType: .custom, authorizationType: .local)
        ServiceContainer.providerService.fetchInfo(for: provider) { result in
            switch result {
            case .success(let info):
                DispatchQueue.main.async {
                    ServiceContainer.providerService.storeProvider(provider: info.provider)
                    self.mainWindowController?.dismiss()
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    let alert = NSAlert(customizedError: error)
                    alert?.beginSheetModal(for: self.view.window!) { (_) in
                        
                    }
                }
            }
        }
    }
    
    @IBAction func chooseConfigFile(_ sender: Any) {
        guard let window = view.window else {
            return
        }
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedFileTypes = ["ovpn"]
        panel.prompt = NSLocalizedString("Add", comment: "")
        panel.beginSheetModal(for: window) { (response) in
            switch response {
            case .OK:
                if let url = panel.urls.first {
                    self.chooseConfigFile(configFileURL: url)
                }
            default:
                break
            }
        }
    }
    
    private func chooseConfigFile(configFileURL: URL, recover: Bool = false) {
        ServiceContainer.providerService.addProvider(configFileURL: configFileURL, recover: recover) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.mainWindowController?.dismiss()
                case .failure(let error):
                    let alert = NSAlert(customizedError: error)
                    if let error = error as? ProviderService.Error, !error.recoveryOptions.isEmpty {
                        error.recoveryOptions.forEach {
                            alert?.addButton(withTitle: $0)
                        }
                    }
                    
                    alert?.beginSheetModal(for: self.view.window!) { (response) in
                        switch response.rawValue {
                        case 1000:
                            self.chooseConfigFile(configFileURL: configFileURL, recover: true)
                        default:
                            break
                        }
                    }
                }
            }
        }
    }
    
    private func discoverProviders(connectionType: ConnectionType) {
        secureInternetButton.isEnabled = false
        instituteAccessButton.isEnabled = false
        ServiceContainer.providerService.discoverProviders(connectionType: connectionType) { result in
            switch result {
            case .success(let providers):
                DispatchQueue.main.async {
                    self.mainWindowController?.showChooseProvider(for: connectionType, from: providers)
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    let alert = NSAlert(customizedError: error)
                    alert?.beginSheetModal(for: self.view.window!) { (_) in
                        self.secureInternetButton.isEnabled = true
                        self.instituteAccessButton.isEnabled = true
                    }
                }
            }
        }
    }
}
