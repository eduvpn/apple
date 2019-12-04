//
//  AppCoordinator.swift
//  eduVPN
//
//  Created by Jeroen Leenarts on 08-08-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

import AppAuth
import CoreData
import Moya
import NetworkExtension
import os.log
import PromiseKit
import UserNotifications

#if os(iOS)

import UIKit

extension UINavigationController: Identifiable {}

#elseif os(macOS)

import Cocoa

#endif

// swiftlint:disable type_body_length

class AppCoordinator: RootViewCoordinator {
    
    lazy var tunnelProviderManagerCoordinator: TunnelProviderManagerCoordinator = {
        let tpmCoordinator = TunnelProviderManagerCoordinator()
        tpmCoordinator.viewContext = persistentContainer.viewContext
        tpmCoordinator.start()
        addChildCoordinator(tpmCoordinator)
        tpmCoordinator.delegate = self
        return tpmCoordinator
    }()
    
    let persistentContainer = NSPersistentContainer(name: "EduVPN")
    
    // MARK: - Properties
    
    let accessTokenPlugin = CredentialStorePlugin()
    
    #if os(iOS)
    private var currentDocumentInteractionController: UIDocumentInteractionController?
    #endif

    internal var authorizingDynamicApiProvider: DynamicApiProvider?
    
    var childCoordinators: [Coordinator] = []
    
    // MARK: - App instantiation
    
    var providersViewController: ProvidersViewController!
    
    #if os(iOS)
    
    let storyboard = UIStoryboard(name: "Main", bundle: nil)
    
    let window: UIWindow
    
    let navigationController: UINavigationController = {
        return UIStoryboard(name: "Main", bundle: nil).instantiateViewController(type: UINavigationController.self)
    }()

    let activityViewController: ActivityViewController = {
        let activityViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(type: ActivityViewController.self)
        activityViewController.modalPresentationStyle = .overCurrentContext
        activityViewController.modalTransitionStyle = .crossDissolve
        return activityViewController
    }()

    var rootViewController: UIViewController {
        return providersViewController
    }
    
    #elseif os(macOS)
    
    let storyboard = NSStoryboard(name: "Main", bundle: nil)
    
    let windowController: NSWindowController = {
        return NSStoryboard(name: "Main", bundle: nil).instantiateController(withIdentifier: "MainWindowController")
            as! MainWindowController //swiftlint:disable:this force_cast
    }()
    
    var window: NSWindow? {
        return windowController.window
    }
    
    #endif
    
    // MARK: - Init
    
    #if os(iOS)
    
    public init(window: UIWindow) {
        self.window = window

//        self.navigationController.addChild(self.activityViewController)
//        self.navigationController.view.addSubview(self.activityViewController.view)

        self.window.rootViewController = self.navigationController
        self.window.makeKeyAndVisible()
        
        providePersistentContainer()
    }
    
    #elseif os(macOS)
    
    public init() {
        windowController.window?.makeKeyAndOrderFront(nil)
        providersViewController = windowController.contentViewController?.children.first as? ProvidersViewController
        providePersistentContainer()
    }
    
    func fixAppName(to appName: String) {
        windowController.window?.title = appName
    }
    
    #endif
    
    private func providePersistentContainer() {
        InstancesRepository.shared.loader.persistentContainer = persistentContainer
        InstancesRepository.shared.refresher.persistentContainer = persistentContainer
        ProfilesRepository.shared.refresher.persistentContainer = persistentContainer
    }
    
    // MARK: - Functions
    
    /// Starts the coordinator
    private func instantiateProvidersViewController() {
        #if os(iOS)
        providersViewController = storyboard.instantiateViewController(type: ProvidersViewController.self)
        #endif
        
        persistentContainer.viewContext.automaticallyMergesChangesFromParent = true
        providersViewController.viewContext = persistentContainer.viewContext
        providersViewController.delegate = self
        providersViewController.providerManagerCoordinator = tunnelProviderManagerCoordinator

        #if os(iOS)
        navigationController.viewControllers = [providersViewController]
        #elseif os(macOS)
        
        providersViewController.start()
        #endif
    }
    
    public func start() {
        os_log("Starting App Coordinator", log: Log.general, type: .info)
        persistentContainer.loadPersistentStores { [weak self] (_, error) in
            if let error = error {
                os_log("Unable to Load Persistent Store. %{public}@", log: Log.general, type: .info, error.localizedDescription)
                self?.showError(error)
            } else {
                DispatchQueue.main.async {
                    self?.instantiateProvidersViewController()
                }
            }
        }
        
        // Migration
        persistentContainer.performBackgroundTask { context in
            let profiles = try? Profile.allInContext(context)
            // Make sure all profiles have a UUID
            profiles?.forEach { profile in
                if profile.uuid == nil {
                    profile.uuid = UUID()
                }
            }
            
            // Fix an issue where a slash was missing in the discoveryIdentifiers.
            let targets = [StaticService(type: .instituteAccess),
                           StaticService(type: .secureInternet)].compactMap { $0 }
            
            targets.forEach { target in
                let fetch = InstanceGroup.fetchRequestForEntity(inContext: context)
                fetch.predicate = NSPredicate(format: "discoveryIdentifier == %@", "\(target.baseURL.absoluteString)\(target.path)")
                if let instanceGroups = try? fetch.execute() {
                    instanceGroups.forEach {
                        $0.discoveryIdentifier = "\(target.baseURL.absoluteString)/\(target.path)"
                    }
                }
            }
            
            // Remove groups no longer active in the app due to changed discovery files.
            let activeDiscoveryIdentifiers = targets.map { "\($0.baseURL.absoluteString)/\($0.path)" }
            
            let groups = try? InstanceGroup.allInContext(context)
            let obsoleteGroups = groups?.filter { group in
                guard let discoveryIdentifier = group.discoveryIdentifier else { return false }
                return !activeDiscoveryIdentifiers.contains(discoveryIdentifier)
            }
            obsoleteGroups?.forEach { context.delete($0) }
            
            // We're done, save everything.
            context.saveContext()
        }
    }
    
    func loadCertificate(for api: Api) -> Promise<CertificateModel> {
        guard let dynamicApiProvider = DynamicApiProvider(api: api) else {
            return Promise(error: AppCoordinatorError.apiProviderCreateFailed)
        }
        
        if let certificateModel = api.certificateModel {
            if let certificate = certificateModel.x509Certificate, certificate.checkValidity() {
                return checkCertificate(api: api, for: dynamicApiProvider).recover { error -> Promise<CertificateModel> in
                    switch error {
                        
                    case AppCoordinatorError.certificateInvalid, AppCoordinatorError.certificateNil, AppCoordinatorError.certificateCommonNameNotFound:
                        api.certificateModel = nil
                        return self.loadCertificate(for: api)
                        
                    default:
                        throw error
                        
                    }
                }
            } else {
                api.certificateModel = nil
            }
        }
        
        guard let appName: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String else {
            fatalError("An app should always have a `CFBundleName`.")
        }
        #if os(iOS)
        let keyPairDisplayName = "\(appName) for iOS"
        #elseif os(macOS)
        let keyPairDisplayName = "\(appName) for macOS"
        #endif
        
        return dynamicApiProvider.request(apiService: .createKeypair(displayName: keyPairDisplayName))
            .recover { error throws -> Promise<Response> in
                switch error {
                    
                case ApiServiceError.noAuthState:
                    #if os(iOS)
                    
                    let authorize = dynamicApiProvider.authorize(presentingViewController: self.navigationController)
                    
                    #elseif os(macOS)
                    
                    let authorize = dynamicApiProvider.authorize()
                    
                    #endif
                    
                    return authorize.then { _ -> Promise<Response> in
                        return dynamicApiProvider.request(apiService: .createKeypair(displayName: keyPairDisplayName))
                    }
                    
                default:
                    throw error
                    
                }
            }
            .then { response -> Promise<CertificateModel> in response.mapResponse() }
            .map { model -> CertificateModel in
                api.certificateModel = model
                self.scheduleCertificateExpirationNotification(for: model, on: api)
                return model
            }
    }
    
    func checkCertificate(api: Api, for dynamicApiProvider: DynamicApiProvider) -> Promise<CertificateModel> {
        guard let certificateModel = api.certificateModel else {
            return Promise<CertificateModel>(error: AppCoordinatorError.certificateNil)
        }
        
        guard let commonNameElements = certificateModel.x509Certificate?.subjectDistinguishedName?.split(separator: "=") else {
            return Promise<CertificateModel>(error: AppCoordinatorError.certificateCommonNameNotFound)
        }
        
        guard commonNameElements.count == 2, commonNameElements[0] == "CN" else {
            return Promise<CertificateModel>(error: AppCoordinatorError.certificateCommonNameNotFound)
        }
        
        let commonName = String(commonNameElements[1])
        return dynamicApiProvider.request(apiService: .checkCertificate(commonName: commonName)).then { response throws -> Promise<CertificateModel> in
            
            if response.statusCode == 404 {
                return .value(certificateModel)
            }
            
            if let jsonResult = try response.mapJSON() as? [String: AnyObject],
                let checkResult = jsonResult["check_certificate"] as? [String: AnyObject],
                let dataResult = checkResult["data"] as? [String: AnyObject],
                let isValidResult = dataResult["is_valid"] as? Bool {
                
                if isValidResult {
                    return .value(certificateModel)
                } else {
                    api.certificateModel = nil
                    throw AppCoordinatorError.certificateInvalid
                }
            } else {
                throw AppCoordinatorError.certificateStatusUnknown
            }
        }.recover { (error) throws -> Promise<CertificateModel> in
            if case ApiServiceError.unauthorized = error {
                #if os(iOS)
                
                return dynamicApiProvider.authorize(presentingViewController: self.navigationController).then { _ -> Promise<CertificateModel> in
                    return self.checkCertificate(api: api, for: dynamicApiProvider)
                }
                
                #elseif os(macOS)
                
                return dynamicApiProvider.authorize().then { _ -> Promise<CertificateModel> in
                    return self.checkCertificate(api: api, for: dynamicApiProvider)
                }
                
                #endif
               
            }

            throw error
        }
    }
    
    func addProvider(animated: Bool = true) {
        // We can not create a static service, so no discovery files are defined. Fall back to adding "another" service.
        if StaticService(type: .instituteAccess) == nil {
            #if os(iOS)
            showCustomProviderInputViewController(for: .other)
            #elseif os(macOS)
            showProfilesViewController(animated: animated)
            #endif
        } else {
            showProfilesViewController(animated: animated)
        }
    }
    
    private func _scheduleCertificateExpirationNotification(for certificate: CertificateModel, on api: Api) {
        guard let expirationDate = certificate.x509Certificate?.notAfter else { return }
        guard let identifier = certificate.uniqueIdentifier else { return }
        
        let notificationTitle = NSLocalizedString("VPN certificate is expiring", comment: "")
        
        var notificationBody: String?
        if let certificateTitle = api.instance?.displayNames?.localizedValue {
            notificationBody = String.localizedStringWithFormat("Once expired the certificate for instance %@ needs to be refreshed.", certificateTitle)
        }
        
        let notification = NotificationsService.makeNotification(title: notificationTitle, body: notificationBody)
        
        #if DEBUG
        
        guard let expirationWarningDate = NSCalendar.current.date(byAdding: .second, value: 10, to: Date()) else { return }
        let expirationWarningDateComponents = NSCalendar.current.dateComponents(in: NSTimeZone.default, from: expirationWarningDate)
        
        #else
        
        guard let expirationWarningDate = (expirationDate.timeIntervalSinceNow < 86400 * 7) ? (NSCalendar.current.date(byAdding: .day, value: -7, to: expirationDate)) : (NSCalendar.current.date(byAdding: .minute, value: 10, to: Date())) else { return }
        
        var expirationWarningDateComponents = NSCalendar.current.dateComponents(in: NSTimeZone.default, from: expirationWarningDate)
        
        // Configure the trigger for 10am.
        expirationWarningDateComponents.hour = 10
        expirationWarningDateComponents.minute = 0
        expirationWarningDateComponents.second = 0
        
        #endif

        os_log("Scheduling a cert expiration reminder for %{public}@ on %{public}@.", log: Log.general, type: .info, certificate.uniqueIdentifier ?? "", expirationDate.description)
        NotificationsService.sendNotification(notification, withIdentifier: identifier, at: expirationWarningDateComponents) { error in
            if let error = error {
                os_log("Error occured when scheduling a cert expiration reminder %{public}@",
                       log: Log.general,
                       type: .info, error.localizedDescription)
            }
        }
    }
    
    fileprivate func scheduleCertificateExpirationNotification(for certificate: CertificateModel, on api: Api) {
        NotificationsService.permissionGranted {
            if $0 {
                self._scheduleCertificateExpirationNotification(for: certificate, on: api)
            } else {
                os_log("Not Authorised", log: Log.general, type: .info)
            }
        }
    }
    
    func resumeAuthorizationFlow(url: URL) -> Bool {
        if let authorizingDynamicApiProvider = authorizingDynamicApiProvider {
            guard let authFlow = authorizingDynamicApiProvider.currentAuthorizationFlow else {
                os_log("Resume authrorization attempted, no current authFlow available", log: Log.general, type: .error)
                self.showNoAuthFlowAlert()
                return false
            }
            if authFlow.resumeExternalUserAgentFlow(with: url) {
                let authorizationType = authorizingDynamicApiProvider.api.instance?.group?.authorizationTypeEnum ?? .local
                if authorizationType == .distributed {
                    authorizingDynamicApiProvider.api.managedObjectContext?.performAndWait {
                        authorizingDynamicApiProvider.api.instance?.group?.distributedAuthorizationApi = authorizingDynamicApiProvider.api
                    }
                    
                    do {
                        try authorizingDynamicApiProvider.api.managedObjectContext?.save()
                    } catch {
                        authorizingDynamicApiProvider.currentAuthorizationFlow = nil
                        return false
                    }
                }
                
                authorizingDynamicApiProvider.currentAuthorizationFlow = nil
                return true
            }
        }
        
        return false
    }
    
    func systemMessages(for dynamicApiProvider: DynamicApiProvider) -> Promise<SystemMessages> {
        return dynamicApiProvider.request(apiService: .systemMessages)
            .then { response -> Promise<SystemMessages> in response.mapResponse() }
    }
    
    /// merge ovpn profile with keypair
    internal func merge(key: String, certificate: String, into ovpnFileContent: String) throws -> String {
        var ovpnFileContent = ovpnFileContent
        
        guard let caRange = ovpnFileContent.range(of: "</ca>") else {
            throw AppCoordinatorError.ovpnTemplate
        }
        let insertionIndex = caRange.upperBound
        ovpnFileContent.insert(contentsOf: "\n<key>\n\(key)\n</key>", at: insertionIndex)
        ovpnFileContent.insert(contentsOf: "\n<cert>\n\(certificate)\n</cert>", at: insertionIndex)
        ovpnFileContent = ovpnFileContent.replacingOccurrences(of: "auth none\r\n", with: "")
        
        return ovpnFileContent
    }
    
    internal func forceTcp(on ovpnFileContent: String) -> String {
        guard UserDefaults.standard.forceTcp else {
            return ovpnFileContent
        }
        
        var ovpnFileContent = ovpnFileContent
        guard let remoteUdpRegex = try? NSRegularExpression(pattern: "remote.*udp", options: []) else {
            fatalError("Regular expression has been validated to compile, should not fail.")
        }
        
        ovpnFileContent = remoteUdpRegex.stringByReplacingMatches(in: ovpnFileContent,
                                                                  options: [],
                                                                  range: NSRange(location: 0,
                                                                                 length: ovpnFileContent.utf16.count),
                                                                  withTemplate: "")
        
        return ovpnFileContent
    }
    
    internal func validateRemote(on ovpnFileContent: String) throws {
        guard let remoteTcpRegex = try? NSRegularExpression(pattern: "remote.*", options: []) else {
            fatalError("Regular expression has been validated to compile, should not fail.")
        }
        
        if remoteTcpRegex.numberOfMatches(in: ovpnFileContent, options: [], range: NSRange(location: 0, length: ovpnFileContent.utf16.count)) == 0 {
            throw AppCoordinatorError.ovpnConfigTemplateNoRemotes
        }
    }
}
