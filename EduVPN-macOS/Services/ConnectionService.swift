//
//  ConnectionService.swift
//  eduVPN
//
//  Created by Johan Kool on 30/06/2017.
//  Copyright © 2017-2019 Commons Conservancy.
//

import Foundation
import AppKit
import ServiceManagement
import AppAuth
import Socket
import SecurityInterface

typealias Config = String

/// Connects to VPN
class ConnectionService: NSObject {
    
    static let openVPNSubdirectory = Bundle.main.infoDictionary!["OpenVPNVersion"] as! String
    
    /// Notification posted when connection state changes
    static let stateChanged = NSNotification.Name("ConnectionService.stateChanged")
    
    /// Connection state
    ///
    /// - connecting: Service is attempting to connect
    /// - connected: Service is connected
    /// - disconnecting: Service is attempting to disconnect
    /// - disconnected: Service is disconnected
    enum State: Equatable {
        case connecting
        case connected
        case disconnecting
        case disconnected
    }
    
    enum Error: Swift.Error, LocalizedError {
        case noHelperConnection
        case statisticsUnavailable
        case unexpectedState
        case logsUnavailable
        case invalidTwoFactorPassword
        case invalidCredentials
        case unexpectedError
        case userCancelled
        case tlsError
        case userIsDisabled

        var errorDescription: String? {
            switch self {
            case .noHelperConnection:
                return NSLocalizedString("Installation failed", comment: "")
            case .statisticsUnavailable:
                return NSLocalizedString("No connection statistics available", comment: "")
            case .unexpectedState:
                return NSLocalizedString("Connection in unexpected state", comment: "")
            case .logsUnavailable:
                return NSLocalizedString("No logs available", comment: "")
            case .invalidTwoFactorPassword:
                return NSLocalizedString("Invalid or expired two factor authentication code", comment: "")
            case .invalidCredentials:
                return NSLocalizedString("Invalid credentials", comment: "")
            case .unexpectedError:
                return NSLocalizedString("Connection encountered unexpected error", comment: "")
            case .tlsError:
                return NSLocalizedString("Signing failed", comment: "")
            case .userCancelled:
                return nil
            case .userIsDisabled:
                return NSLocalizedString("User account is disabled", comment: "")
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .noHelperConnection:
                return NSLocalizedString("Try reinstalling eduVPN.", comment: "")
            case .statisticsUnavailable, .logsUnavailable:
                return NSLocalizedString("Try again later.", comment: "")
            case .invalidTwoFactorPassword, .invalidCredentials:
                return NSLocalizedString("Verify and try again.", comment: "")
            case .tlsError:
                return NSLocalizedString("Verify that you are using the correct certificate and try again.", comment: "")
            case .unexpectedState, .unexpectedError:
                return NSLocalizedString("Try again.", comment: "")
            case .userCancelled:
                return nil
            case .userIsDisabled:
                return NSLocalizedString("Contact your administrator for further details", comment: "")
            }
        }
    }
    
    private var pendingDisconnectHandlers: [((Result<Void>) -> ())] = []
    
    /// Describes current connection state
    private(set) var state: State = .disconnected {
        didSet {
            if state == .connected {
                didConnect()
            }
            if oldValue == .disconnecting && state == .disconnected && !pendingDisconnectHandlers.isEmpty {
                for handler in pendingDisconnectHandlers {
                    handler(.success(Void()))
                }
                pendingDisconnectHandlers = []
            }
            if oldValue != state {
                NotificationCenter.default.post(name: ConnectionService.stateChanged, object: self)
            }
        }
    }
    
    private let providerService: ProviderService
    private let configurationService: ConfigurationService
    private let helperService: HelperService
    private let keychainService: KeychainService
    private let preferencesService: PreferencesService
    
    init(providerService: ProviderService, configurationService: ConfigurationService, helperService: HelperService, keychainService: KeychainService, preferencesService: PreferencesService) {
        self.providerService = providerService
        self.configurationService = configurationService
        self.helperService = helperService
        self.keychainService = keychainService
        self.preferencesService = preferencesService
    }
    
    /// Asks helper service to start VPN connection after helper and config are ready and available
    ///
    /// - Parameters:
    ///   - profile: Profile
    ///   - twoFactor: Optional two factor authentication token
    ///   - handler: Success or error
    func connect(to profile: Profile, twoFactor: TwoFactor?, handler: @escaping (Result<Void>) -> ()) {
        guard state == .disconnected else {
            handler(.failure(Error.unexpectedState))
            return
        }
        state = .connecting
        
        // Reset
        bytesIn = 0
        bytesOut = 0
        startDate = Date()
        openVPNState = .unknown
        openVPNStateDescription = nil
        localTUNTAPIPv4Address = nil
        remoteIPv4Address = nil
        remotePort = nil
        localIPv4Address = nil
        localPort = nil
        localTUNTAPIPv6Address = nil
        currentProfile = nil
        credentials = nil
        
        helperService.installHelperIfNeeded(client: self) { (result) in
            switch result {
            case .success:
                self.configurationService.configure(for: profile) { (result) in
                    switch result {
                    case .success(let config, let certificateCommonName):
                        do {
                            let configURL = try self.install(config: config)
                            self.twoFactor = twoFactor
                            self.commonNameCertificate = certificateCommonName
                            self.currentProfile = profile
                            self.activateConfig(at: configURL, handler: handler)
                        } catch(let error) {
                            self.coolDown()
                            handler(.failure(error))
                        }
                    case .failure(let error):
                        self.coolDown()
                        handler(.failure(error))
                    }
                }
            case .failure(let error):
                self.coolDown()
                handler(.failure(error))
            }
        }
    }
    
    /// Sets state to disconnected after a cool down perios
    ///
    /// Some actions are still going on when disconnecting, going directly to disconnected state allows user to immediately reconnect, which can get the app the behave unexpectedly.
    private func coolDown(_ handler: ((Result<Void>) -> ())? = nil) {
        guard state != .disconnected else {
            handler?(.success(Void()))
            return
        }

        if let handler = handler {
            pendingDisconnectHandlers.append(handler)
        }

        if self.state == .disconnecting {
            return
        }

        self.state = .disconnecting
        
        // Wait 6s before actually marking connection as disconnected
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
            self.state = .disconnected
        }
    }
    
    private var currentProfile: Profile?
    
    private func didConnect() {
        guard let provider = currentProfile?.info.provider, provider.connectionType == .localConfig else {
            return
        }
        let username: String?
        if let credentials = credentials, credentials.saveInKeychain {
            do {
                try keychainService.savePassword(service: provider.displayName, account: credentials.username, password: credentials.password)
                username = credentials.username
            } catch {
                username = nil
                debugLog("Keychain error: \(error)")
            }
        } else {
            username = nil
        }
        providerService.saveCommonCertificate(commonNameCertificate, username: username, for: provider)
    }
    
    private func abortConnecting(error: Swift.Error) {
        handler?(.failure(error))
        guard state == .connected || state == .connecting else {
            // Already disconnecting or disconnected
            return
        }
        disconnect { _ in
            // Nothing
        }
    }
    
    /// Installs configuration
    ///
    /// - Parameter config: Config
    /// - Returns: URL where config was installed
    /// - Throws: Error writing config to disk
    private func install(config: String) throws -> URL {
        let tempDir = (NSTemporaryDirectory() as NSString).appendingPathComponent("org.eduvpn.app.temp") // Added .temp because .app lets the Finder show the folder as an app
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true, attributes: nil)
        let fileURL = URL(fileURLWithPath: (tempDir as NSString).appendingPathComponent("eduvpn.ovpn"))
        try config.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
    
    private var twoFactor: TwoFactor?
    private var handler: ((Result<Void>) -> ())?
    
    /// Asks helper service to start VPN connection
    ///
    /// - Parameters:
    ///   - configURL: URL of config file
    ///   - handler: Succes or error
    private func activateConfig(at configURL: URL, handler: @escaping (Result<Void>) -> ()) {
        guard state == .connecting else {
            handler(.failure(Error.unexpectedState))
            return
        }
        
        guard let helper = helperService.connection?.remoteObjectProxy as? OpenVPNHelperProtocol else {
            handler(.failure(Error.noHelperConnection))
            return
        }
        
        let bundle = Bundle.init(for: ConnectionService.self)
        let openvpnURL = bundle.url(forResource: "openvpn", withExtension: nil, subdirectory: ConnectionService.openVPNSubdirectory)!
        let upScript = bundle.url(forResource: "client.up.eduvpn", withExtension: "sh", subdirectory: ConnectionService.openVPNSubdirectory)!
        let downScript = bundle.url(forResource: "client.down.eduvpn", withExtension: "sh", subdirectory: ConnectionService.openVPNSubdirectory)!
        let leasewatchPlist = URL(fileURLWithPath: "/Library/Application Support/eduVPN/LeaseWatch.plist")
        let leasewatchScript = bundle.url(forResource: "leasewatch", withExtension: "sh", subdirectory: ConnectionService.openVPNSubdirectory)!
        var scriptOptions = [
            "-6" /* ARG_ENABLE_IPV6_ON_TAP */,
            "-f" /* ARG_FLUSH_DNS_CACHE */,
            "-o" /* ARG_OVERRIDE_MANUAL_NETWORK_SETTINGS */,
            "-r" /* ARG_RESET_PRIMARY_INTERFACE_ON_DISCONNECT */,
            "-w" /* ARG_RESTORE_ON_WINS_RESET */,
            "-m" /* ARG_MONITOR_NETWORK_CONFIGURATION */,
            "-t" /* ARG_TB_PATH */,
            bundle.bundlePath
        ]
        let developerMode = preferencesService.developerMode
        if developerMode {
            scriptOptions.append("-l" /* ARG_EXTRA_LOGGING */)
        }
        
        self.configURL = configURL
        helper.startOpenVPN(at: openvpnURL, withConfig: configURL, upScript: upScript, downScript: downScript, leasewatchPlist: leasewatchPlist, leasewatchScript: leasewatchScript, scriptOptions: scriptOptions) { (error) in
            if let error = error as NSError? {
                self.coolDown()
                self.configURL = nil

                handler(.failure(error))
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.openManagingSocket()
                }
                self.handler = handler
                handler(.success(Void()))
            }
        }
    }
    
    /// Uninstalls file
    ///
    /// - Parameter fileURL: URL where file was installed
    /// - Throws: Error removing file from disk
    private func uninstall(fileURL: URL) {
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch(let error) {
            print("Failed to remove file at URL %@ with error: %@", fileURL, error)
        }
    }
    
    /// Asks helper to disconnect VPN connection
    ///
    /// - Parameter handler: Success or error
    func disconnect(_ handler: @escaping (Result<Void>) -> ()) {
        guard state == .connected || state == .connecting else {
            handler(.failure(Error.unexpectedState))
            return
        }
        
        guard let helper = helperService.connection?.remoteObjectProxy as? OpenVPNHelperProtocol else {
            self.state = .connected
            handler(.failure(Error.noHelperConnection))
            return
        }
        
        helper.close {
            self.configURL = nil
            self.twoFactor = nil
            self.handler = nil
            self.closeManagingSocket(force: false)
            self.coolDown(handler)
        }
    }
    
    /// URL to the last loaded config (which may have been deleted already!)
    private(set) var configURL: URL? {
        didSet(oldValue) {
            if let oldURL = oldValue {
                uninstall(fileURL: oldURL)
            }
        }
    }
    
    /// URL to the log file
    var logURL: URL? {
        return configURL?.appendingPathExtension("log")
    }
    
    // MARK: - Socket
    
    /// Path to socket
    private let socketPath = "/private/tmp/eduvpn.socket"
    
    private var socket: Socket?
    private var managing: Bool = false
    private var commonNameCertificate: String = ""
    private var credentials: (username: String, password: String, saveInKeychain: Bool)?
    
    private func openManagingSocket() {
        let queue = DispatchQueue.global(qos: .userInteractive)
        
        queue.async { [unowned self] in
            
            do {
                let socket = try Socket.create(family: .unix, type: .stream, proto: .unix)
                self.socket = socket
                
                try socket.connect(to: self.socketPath)
                
                self.managing = true
                
                try _ = Socket.wait(for: [socket], timeout: 10_000 /* ms */)
                
                repeat {
                    if let string = try socket.readString() {
                        try self.parseRead(string)
                    }
                } while self.managing
                
            } catch {
                debugLog(error)
                self.handler?(.failure(error))
            }
            
        }
        
    }
    
    // See https://github.com/OpenVPN/openvpn/blob/master/doc/management-notes.txt
    private func parseRead(_ string: String) throws {
        let stringToParse: String
        let remainder: String?
        
        if let range = string.range(of: "\r\n>") {
            // Multiple commands in string, split and parse separately
            let index = string.index(range.upperBound, offsetBy: -1)
            stringToParse = String(string[..<index])
            remainder = String(string[index...])
        } else {
            stringToParse = string
            remainder = nil
        }
        
        guard stringToParse.hasPrefix(">") else {
            // It's a response, not a command
            debugLog("<<< " + stringToParse)
            if let remainder = remainder {
                try parseRead(remainder)
            }
            return
        }
        
        debugLog("CMD " + stringToParse)
        
        let argumentString: String?
        if let start = stringToParse.range(of: ":")?.upperBound {
            let end = stringToParse.range(of: "\r\n")?.lowerBound ?? stringToParse.endIndex
            argumentString = String(stringToParse[start..<end])
        } else {
            argumentString = nil
        }
        
        let components = stringToParse.split(separator: ":")
        
        guard let command = components.first else {
            return
        }
        
        switch String(command) {
        case ">INFO":
            try enableStateAndByteCountNotificatons()
        case ">NEED-CERTIFICATE":
            try needCertificate()
        case ">RSA_SIGN":
            guard let argumentString = argumentString else {
                return
            }
            try rsaSign(argumentString)
        case ">STATE":
            guard let argumentString = argumentString else {
                return
            }
            parseState(argumentString)
        case ">BYTECOUNT":
            guard let argumentString = argumentString else {
                return
            }
            parseByteCounts(argumentString)
        case ">PASSWORD":
            guard let argumentString = argumentString else {
                return
            }
            try needPassword(argumentString)
        default:
            break
        }
        
        if let remainder = remainder {
            try parseRead(remainder)
        }
    }
    
    private func write(_ string: String) throws {
        debugLog(">>> " + string)
        try socket?.write(from: string)
    }
    
    private func enableStateAndByteCountNotificatons() throws {
        try write("state on\nbytecount 1\n")
    }
    
    enum OpenVPNState: String {
        case unknown
        case connecting = "CONNECTING"      // OpenVPN's initial state.
        case waiting = "WAIT"               // (Client only) Waiting for initial response from server.
        case authenticating = "AUTH"        // (Client only) Authenticating with server.
        case fetchingConfig = "GET_CONFIG"  // (Client only) Downloading configuration options from server.
        case assigningIP = "ASSIGN_IP"      // Assigning IP address to virtual network interface.
        case addingRoutes = "ADD_ROUTES"    // Adding routes to system.
        case connected = "CONNECTED"        // Initialization Sequence Completed.
        case reconnecting = "RECONNECTING"  // A restart has occurred.
        case exiting = "EXITING"            // A graceful exit is in progress.
        case resolving = "RESOLVE"          // (Client only) DNS lookup
        case connectingTCP = "TCP_CONNECT"  // (Client only) Connecting to TCP server
        
        var localizedDescription: String? {
            switch self {
            case .unknown:
                return nil
            case .connecting:
                return NSLocalizedString("Connecting", comment: "")
            case .waiting:
                return NSLocalizedString("Waiting for initial response from server", comment: "")
            case .authenticating:
                return NSLocalizedString("Authenticating with server", comment: "")
            case .fetchingConfig:
                return NSLocalizedString("Downloading configuration options from server", comment: "")
            case .assigningIP:
                return NSLocalizedString("Assigning IP address to virtual network interface", comment: "")
            case .addingRoutes:
                return NSLocalizedString("Adding routes to system", comment: "")
            case .connected:
                return NSLocalizedString("Connected", comment: "")
            case .reconnecting:
                return NSLocalizedString("Reconnecting", comment: "")
            case .exiting:
                return NSLocalizedString("Disconnected", comment: "")
            case .resolving :
                return NSLocalizedString("Performing DNS lookup", comment: "")
            case .connectingTCP:
                return NSLocalizedString("Connecting to TCP server", comment: "")
            }
        }
    }
    
    private(set) var openVPNState: OpenVPNState = .unknown {
        didSet {
            switch openVPNState {
            case .connected:
                state = .connected
            case .reconnecting:
                state = .connecting
            case .exiting:
                coolDown()
            default:
                break
            }
        }
    }
    private(set) var openVPNStateDescription: String? = nil
    private(set) var localTUNTAPIPv4Address: String?
    private(set) var remoteIPv4Address: String?
    private(set) var remotePort: String?
    private(set) var localIPv4Address: String?
    private(set) var localPort: String?
    private(set) var localTUNTAPIPv6Address: String?
    
    private func parseState(_ string: String) {
        let components = string.components(separatedBy: ",")
        guard components.count >= 8 else {
            // When returning certain states OpenVPN forgets one comma
            return
        }
        
        // The output format consists of up to 9 comma-separated parameters:
        
        // (a) the integer unix date/time
        // ignored
        
        // (b) the state name,
        openVPNState = OpenVPNState(rawValue: String(components[1])) ?? .unknown
        
        // (c) optional descriptive string (used mostly on RECONNECTING and EXITING to show the reason for the disconnect)
        openVPNStateDescription = String(components[2])
        
        if openVPNState == .reconnecting && openVPNStateDescription == "tls-error" {
            // Wrong certificate, signing wil fail, abort connecting
            abortConnecting(error: Error.tlsError)
        }
        
        // (d) optional TUN/TAP local IPv4 address
        localTUNTAPIPv4Address = String(components[3])
        
        // (e) optional address of remote server
        remoteIPv4Address = String(components[4])
        
        // (f) optional port of remote server
        remotePort = String(components[5])
        
        // (g) optional local address
        localIPv4Address = String(components[6])
        
        // (h) optional local port
        localPort = String(components[7])
        
        guard components.count == 9 else {
            // Unexpected number of parameters
            return
        }
        
        // (i) optional TUN/TAP local IPv6 address.
        localTUNTAPIPv6Address = String(components[8])
    }
    
    private(set) var bytesIn: Int = 0
    private(set) var bytesOut: Int = 0
    private var startDate: Date = Date()
    var duration: DateComponents {
        return Calendar.current.dateComponents([.hour, .minute, .second], from: startDate, to: Date())
    }
    
    private func parseByteCounts(_ string: String) {
        let components = string.components(separatedBy: ",")
        guard components.count == 2 else {
            return
        }
        bytesIn = Int(components[0]) ?? bytesIn
        bytesOut = Int(components[1]) ?? bytesOut
    }
    
    private func needCertificate() throws {
        if commonNameCertificate == "" {
            let query: NSDictionary = [kSecClass: kSecClassIdentity, kSecMatchLimit: kSecMatchLimitAll] // This could be stricter?
            
            var result: AnyObject?
            
            let lastResultCode = withUnsafeMutablePointer(to: &result) {
                SecItemCopyMatching(query as CFDictionary, UnsafeMutablePointer($0))
            }
            
            if lastResultCode == noErr {
                let array = result as? Array<SecIdentity>
                
                DispatchQueue.main.async {
                    let panel = SFChooseIdentityPanel.shared()!
                    self.identityPanel = panel
                    panel.setInformativeText(NSLocalizedString("Your choice will be remembered for future use.", comment: ""))
                    panel.setAlternateButtonTitle(NSLocalizedString("Cancel", comment: ""))
                    let message = NSLocalizedString("Choose the certificate you want to use for this connection", comment: "")
                    let window = NSApp.mainWindow
                    panel.beginSheet(for: window, modalDelegate: self, didEnd: #selector(ConnectionService.chooseIdentitySheetDidEnd(sheet:returnCode:contextInfo:)), contextInfo: nil, identities: array, message: message)
                }
            }
            return
        }
        
        let certificate = try keychainService.certificate(for: commonNameCertificate)
        let certificateString = certificate.base64EncodedString(options: [.lineLength64Characters])
        let response = "certificate\n-----BEGIN CERTIFICATE-----\n\(certificateString)\n-----END CERTIFICATE-----\nEND\n"
        try write(response)
    }
    
    private var identityPanel: SFChooseIdentityPanel?
    
    @objc func chooseIdentitySheetDidEnd(sheet: SFChooseIdentityPanel, returnCode: NSApplication.ModalResponse, contextInfo: AnyObject?) {
        guard let identityPanel = identityPanel else {
            return
        }
        do {
            switch returnCode {
            case .OK:
                let identity = identityPanel.identity().takeUnretainedValue()
                let certificate = try self.keychainService.certificate(for: identity)
                let certificateString = certificate.base64EncodedString(options: [.lineLength64Characters])
                self.commonNameCertificate = (try? self.keychainService.commonName(for: identity)) ?? ""
                let response = "certificate\n-----BEGIN CERTIFICATE-----\n\(certificateString)\n-----END CERTIFICATE-----\nEND\n"
                try self.write(response)
            default:
                abortConnecting(error: Error.userCancelled)
            }
        }
        catch {
            abortConnecting(error: error)
        }
    }
    
    private func needPassword(_ string: String) throws {
        switch string {
        case "Need \'Auth\' username/password":
            break
        case "Verification Failed: \'Auth\'":
            if twoFactor == nil {
                // Remove from keychain on fail
                if let provider = currentProfile?.info.provider, let username = provider.username {
                    try keychainService.removePassword(service: provider.displayName, account: username)
                }
                if let provider = currentProfile?.info.provider, provider.connectionType == .custom {
                    throw Error.invalidCredentials
                } else {
                    throw Error.userIsDisabled
                }
            } else {
                throw Error.invalidTwoFactorPassword
            }
        default:
            return
        }
        
        guard let twoFactor = twoFactor else {
            requestCredentials()
            return
        }
        let username: String
        let password: String
        switch twoFactor {
        case .totp(let token):
            username = "totp"
            password = token
        case .yubico(let token):
            username = "yubi"
            password = token
        }
        let response = "username \"Auth\" \(username)\npassword \"Auth\" \(password)\n"
        try write(response)
    }
    
    private func requestCredentials() {
        if let provider = currentProfile?.info.provider, let username = provider.username, let password = try? keychainService.loadPassword(service: provider.displayName, account: username) {
            guard let password = password else {
                return
            }
            do {
                let response = "username \"Auth\" \(username)\npassword \"Auth\" \(password)\n"
                try self.write(response)
            } catch {
                self.abortConnecting(error: error)
            }
            return
        }
        
        DispatchQueue.main.async {
            let window = NSApp.mainWindow!
            let storyboard = NSStoryboard(name: "Main", bundle: nil)
            let enterCredentialsViewController = storyboard.instantiateController(withIdentifier: "EnterCredentials") as! EnterCredentialsViewController
            let panel = NSPanel(contentViewController: enterCredentialsViewController)
            window.beginSheet(panel) { (response) in
                switch response {
                case .OK:
                    guard let credentials = enterCredentialsViewController.credentials else {
                        self.abortConnecting(error: Error.unexpectedError)
                        return
                    }
                    do {
                        let response = "username \"Auth\" \(credentials.username)\npassword \"Auth\" \(credentials.password)\n"
                        if credentials.saveInKeychain {
                            self.credentials = credentials
                        }
                        try self.write(response)
                    } catch {
                        self.abortConnecting(error: error)
                    }
                default:
                    self.abortConnecting(error: Error.userCancelled)
                    break
                }
            }
        }
    }
    
    private func rsaSign(_ stringToSign: String) throws {
        guard let data = Data(base64Encoded: stringToSign, options: [.ignoreUnknownCharacters]) else {
            throw Error.unexpectedError
        }
        do {
            let signature = try keychainService.sign(using: commonNameCertificate, dataToSign: data)
            let signatureString = signature.base64EncodedString(options: [.lineLength64Characters])
            let response = "rsa-sig\n\(signatureString)\nEND\n"
            try write(response)
        } catch {
            abortConnecting(error: error)
        }
    }
    
    private func closeManagingSocket(force: Bool) {
        managing = false
        if force {
            do {
                try write("signal SIGTERM\n")
            } catch {
                debugLog(error)
            }
        }
        socket?.close()
    }
    
    func closeOrphanedConnectionIfNeeded(handler: @escaping (Bool) -> Void) {
        guard FileManager.default.fileExists(atPath: socketPath) else {
            handler(false)
            return
        }
        
        let queue = DispatchQueue.global(qos: .userInteractive)
        queue.async { [unowned self] in
            do {
                let socket = try Socket.create(family: .unix, type: .stream, proto: .unix)
                self.socket = socket
                
                try socket.connect(to: self.socketPath)
                
                try _ = Socket.wait(for: [socket], timeout: 10_000 /* ms */)
                
                self.closeManagingSocket(force: true)
                
                // Allow some time to close up
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    handler(true)
                }
            } catch {
                debugLog(error)
            }
        }
    }
    
}

extension ConnectionService: ClientProtocol {
    
    func taskTerminated(reply: @escaping () -> Void) {
        reply()
        coolDown()
        configURL = nil
        handler = nil
    }
    
}

