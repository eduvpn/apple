//
//  AppCoordinator.swift
//  eduVPN
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
    
    let config: Config
    let instancesRepository: InstancesRepository
    let organizationsRepository: OrganizationsRepository
    let serversRepository: ServersRepository
    
    lazy var tunnelProviderManagerCoordinator: TunnelProviderManagerCoordinator = {
        let tpmCoordinator = TunnelProviderManagerCoordinator()
        tpmCoordinator.viewContext = persistentContainer.viewContext
        tpmCoordinator.start()
        addChildCoordinator(tpmCoordinator)
        tpmCoordinator.delegate = self
        return tpmCoordinator
    }()
    
    let persistentContainer = NSPersistentContainer(name: "EduVPN")
    let notificationsService = NotificationsService()
    
    // MARK: - Properties
    
    let accessTokenPlugin = CredentialStorePlugin()
    
    internal var authorizingDynamicApiProvider: DynamicApiProvider?
    
    var childCoordinators: [Coordinator] = []
    
    // MARK: - App instantiation
    
    var providersViewController: ProvidersViewController!
    var serversViewController: ServersViewController!
    
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
    
    public init(window: UIWindow, config: Config = Config.shared, instancesRepository: InstancesRepository = InstancesRepository(),  organizationsRepository: OrganizationsRepository = OrganizationsRepository(), serversRepository: ServersRepository = ServersRepository()) {
        self.window = window
        self.config = config
        self.instancesRepository = instancesRepository
        self.organizationsRepository = organizationsRepository
        self.serversRepository = serversRepository
        
        self.window.rootViewController = self.navigationController
        self.window.makeKeyAndVisible()
        
        providePersistentContainer()
    }
    
    #elseif os(macOS)
    
    public init(config: Config = Config.shared, instancesRepository: InstancesRepository = InstancesRepository(), organizationsRepository: OrganizationsRepository = OrganizationsRepository(), serversRepository: ServersRepository = ServersRepository()) {
        self.config = config
        self.instancesRepository = instancesRepository
        self.organizationsRepository = organizationsRepository
        self.serversRepository = serversRepository
        
        providePersistentContainer()
        
        windowController.window?.makeKeyAndOrderFront(nil)
    }
    
    func fixAppName(to appName: String) {
        windowController.window?.title = appName
    }
    
    #endif
    
    private func providePersistentContainer() {
        instancesRepository.loader.persistentContainer = persistentContainer
        instancesRepository.refresher.persistentContainer = persistentContainer
        organizationsRepository.loader.persistentContainer = persistentContainer
        organizationsRepository.refresher.persistentContainer = persistentContainer
        serversRepository.loader.persistentContainer = persistentContainer
     //   serversRepository.refresher.persistentContainer = persistentContainer
        ProfilesRepository.shared.refresher.persistentContainer = persistentContainer
    }
    
    // MARK: - Functions
    
    /// Starts the coordinator
    private func instantiateProvidersViewController() {
        #if os(iOS)
        providersViewController = storyboard.instantiateViewController(type: ProvidersViewController.self)
        #elseif os(macOS)
        providersViewController = windowController.contentViewController?.children.first as? ProvidersViewController
        #endif
        
        persistentContainer.viewContext.automaticallyMergesChangesFromParent = true
        providersViewController.viewContext = persistentContainer.viewContext
        providersViewController.delegate = self

        #if os(iOS)
        navigationController.viewControllers = [providersViewController]
        #elseif os(macOS)
        (windowController as? MainWindowController)?.setRoot(viewController: providersViewController, animated: false) {
            self.providersViewController.start()
        }
        #endif
    }
    
    /// Starts the coordinator for new discovery methor
    private func instantiateServersViewController() {
        #if os(iOS)
        providersViewController = storyboard.instantiateViewController(type: ProvidersViewController.self)
        #elseif os(macOS)
        serversViewController = storyboard.instantiateController(withIdentifier: "Servers") as? ServersViewController
        #endif
        
        persistentContainer.viewContext.automaticallyMergesChangesFromParent = true
        serversViewController.viewContext = persistentContainer.viewContext
        serversViewController.delegate = self

        #if os(iOS)
        navigationController.viewControllers = [serversViewController]
        #elseif os(macOS)
        (windowController as? MainWindowController)?.setRoot(viewController: serversViewController, animated: false) {
            self.serversViewController.start()
        }
        #endif
    }
    
    func connect(url: URL) -> Promise<Void> {
        return Promise<Instance>(resolver: { seal in
            persistentContainer.performBackgroundTask { context in
                let instanceGroupIdentifier = url.absoluteString
                let predicate = NSPredicate(format: "discoveryIdentifier == %@", instanceGroupIdentifier)
                let group = try! InstanceGroup.findFirstInContext(context, predicate: predicate) ?? InstanceGroup(context: context) //swiftlint:disable:this force_try
                
                let instance = Instance(context: context)
                instance.providerType = ProviderType.other.rawValue
                instance.baseUri = url.absoluteString
                
                let displayName = DisplayName(context: context)
                displayName.displayName = url.host
                instance.addToDisplayNames(displayName)
                instance.group = group
                
                let provider = Custom.init(context: context)
                instance.provider = provider
                instance.isParent = true
                
                do {
                    try context.save()
                } catch {
                    seal.reject(error)
                }
                
                seal.fulfill(instance)
            }
        }).then { instance -> Promise<Void> in
            let instance = self.persistentContainer.viewContext.object(with: instance.objectID) as! Instance //swiftlint:disable:this force_cast
            return self.refresh(instance: instance).then {_ -> Promise<Void> in
                #if os(iOS)
                self.popToRootViewController()
                #elseif os(macOS)
                self.popToRootViewController(animated: false, completionHandler: {
                    self.dismissViewController()
                })
                #endif
                
                return Promise.value(())
            }
        }.recover { error in
            let error = error as NSError
            self.showError(error)
        }
    }
    
    func connect(profile: Profile) {
        if let currentProfileUuid = profile.uuid, currentProfileUuid.uuidString == UserDefaults.standard.configuredProfileId {
            _ = showConnectionViewController(for: profile)
        } else {
            _ = tunnelProviderManagerCoordinator.disconnect()
                .recover { _ in self.tunnelProviderManagerCoordinator.configure(profile: profile) }
                .then { _ -> Promise<Void> in
                    self.providersViewController.tableView.reloadData()
                    return self.showConnectionViewController(for: profile)
                }
        }
    }
    
    public func start() {        
        os_log("Starting App Coordinator", log: Log.general, type: .info)
        persistentContainer.loadPersistentStores { [weak self] (_, error) in
            if let error = error {
                os_log("Unable to Load Persistent Store. %{public}@", log: Log.general, type: .info, error.localizedDescription)
                self?.showError(error)
            } else {
                DispatchQueue.main.async {
                    if UserDefaults.standard.useNewDiscoveryMethod {
                        os_log("Using new discovery method", log: Log.general, type: .info)
                        self?.instantiateServersViewController()
                    } else {
                        os_log("Using old discovery method", log: Log.general, type: .info)
                        self?.instantiateProvidersViewController()
                    }
                }
            }
        }
        
        // Migration
        persistentContainer.performBackgroundTask { context in
            guard UserDefaults.standard.useNewDiscoveryMethod == false else {
                // TODO: See which migration is needed with new discovery method
                // Currently it is too eager and removes everything
                return
            }
            
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
    
    func addProvider(animated: Bool = true, allowClose: Bool) {
        if StaticService(type: .instituteAccess) == nil {
            // We can not create a static service, so no discovery files are defined. Fall back to adding "another" service.
            showCustomProviderInputViewController(for: .other, animated: animated)
        } else {
            if UserDefaults.standard.useNewDiscoveryMethod {
                os_log("Using new discovery method", log: Log.general, type: .info)
                showOrganizationsViewController(animated: animated, allowClose: allowClose)
            } else {
                os_log("Using old discovery method", log: Log.general, type: .info)
                showProfilesViewController(animated: animated)
            }
        }
    }
    
    fileprivate func scheduleCertificateExpirationNotification(for certificate: CertificateModel, on api: Api) {
        notificationsService.permissionGranted {
            if $0 {
                self.notificationsService.scheduleCertificateExpirationNotification(for: certificate, on: api)
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
                let providerType = authorizingDynamicApiProvider.api.instance?.providerType.map { ProviderType(rawValue: $0 ) } ?? .unknown
                if authorizationType == .distributed && providerType != .instituteAccess {
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
