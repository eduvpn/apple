//
//  AppCoordinator.swift
//  EduVPN
//
//  Created by Jeroen Leenarts on 08-08-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

import UIKit
import UserNotifications
import os.log

import Moya
import Disk
import PromiseKit

import CoreData
import BNRCoreDataStack

import AppAuth

import Sodium

import NVActivityIndicatorView

// swiftlint:disable type_body_length
// swiftlint:disable file_length
// swiftlint:disable function_body_length

extension UINavigationController: Identifyable {}

enum AppCoordinatorError: Swift.Error {
    case certificateInvalid
    case certificateNil
    case certificateCommonNameNotFound
    case certificateStatusUnknown
    case apiMissing
    case apiProviderCreateFailed
    case sodiumSignatureFetchFailed
    case sodiumSignatureVerifyFailed
    case ovpnConfigTemplate
    case ovpnConfigTemplateNoRemotes
    
    var localizedDescription: String {
        switch self {
        case .certificateInvalid:
            return NSLocalizedString("VPN certificate is invalid.", comment: "")
        case .certificateNil:
            return NSLocalizedString("VPN certificate should not be nil.", comment: "")
        case .certificateCommonNameNotFound:
            return NSLocalizedString("Unable to extract Common Name from VPN certificate.", comment: "")
        case .certificateStatusUnknown:
            return NSLocalizedString("VPN certificate status is unknown.", comment: "")
        case .apiMissing:
            return NSLocalizedString("No concrete API instance while expecting one.", comment: "")
        case .apiProviderCreateFailed:
            return NSLocalizedString("Failed to create dynamic API provider.", comment: "")
        case .sodiumSignatureFetchFailed:
            return NSLocalizedString("Fetching signature failed.", comment: "")
        case .sodiumSignatureVerifyFailed:
            return NSLocalizedString("Signature verification of discovery file failed.", comment: "")
        case .ovpnConfigTemplate:
            return NSLocalizedString("Unable to materialize an OpenVPN config.", comment: "")
        case .ovpnConfigTemplateNoRemotes:
            return NSLocalizedString("OpenVPN template has no remotes.", comment: "")
        }
    }
}

class AppCoordinator: RootViewCoordinator {

    lazy var tunnelProviderManagerCoordinator: TunnelProviderManagerCoordinator = {
        let tpmCoordinator = TunnelProviderManagerCoordinator()
        self.addChildCoordinator(tpmCoordinator)
        tpmCoordinator.delegate = self
        return tpmCoordinator
    }()
    let persistentContainer = NSPersistentContainer(name: "EduVPN")
    let storyboard = UIStoryboard(name: "Main", bundle: nil)

    // MARK: - Properties

    let accessTokenPlugin =  CredentialStorePlugin()

    private var currentDocumentInteractionController: UIDocumentInteractionController?

    private var authorizingDynamicApiProvider: DynamicApiProvider?

    var childCoordinators: [Coordinator] = []

    var rootViewController: UIViewController {
        return self.providerTableViewController
    }

    var providerTableViewController: ProviderTableViewController!

    /// Window to manage
    let window: UIWindow

    let navigationController: UINavigationController = {
        let navController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(type: UINavigationController.self)
        return navController
    }()

    // MARK: - Init
    public init(window: UIWindow) {
        self.window = window

        self.window.rootViewController = self.navigationController
        self.window.makeKeyAndVisible()
    }

    // MARK: - Functions

    /// Starts the coordinator
    public func start() {
        persistentContainer.loadPersistentStores { [weak self] (_, error) in
            if let error = error {
                os_log("Unable to Load Persistent Store. %{public}@", log: Log.general, type: .info, error.localizedDescription)
            } else {
                DispatchQueue.main.async {
                    
                    //start
                    if let providerTableViewController = self?.storyboard.instantiateViewController(type: ProviderTableViewController.self) {
                        self?.providerTableViewController = providerTableViewController
                        self?.persistentContainer.viewContext.automaticallyMergesChangesFromParent = true
                        self?.providerTableViewController.viewContext = self?.persistentContainer.viewContext
                        self?.providerTableViewController.delegate = self
                        self?.providerTableViewController.providerManagerCoordinator = self?.tunnelProviderManagerCoordinator
                        self?.navigationController.viewControllers = [providerTableViewController]
                        do {
                            if let context = self?.persistentContainer.viewContext, try Profile.countInContext(context) == 0 {
                                if let predefinedProvider = Config.shared.predefinedProvider {
                                    _ = self?.connect(url: predefinedProvider)
                                } else {
                                    self?.addProvider()
                                }
                            }
                        } catch {
                            self?.showError(error)
                        }
                    }
                }
            }
        }
        
        // Migratation
        self.persistentContainer.performBackgroundTask({ (context) in
            let profiles =  try? Profile.allInContext(context)
            profiles?.forEach({ (profile) in
                if profile.uuid == nil {
                    profile.uuid = UUID()
                }
                context.saveContext()
            })
        })

    }

    func loadCertificate(for api: Api) -> Promise<CertificateModel> {
        guard let dynamicApiProvider = DynamicApiProvider(api: api) else { return Promise.init(error: AppCoordinatorError.apiProviderCreateFailed) }

        if let certificateModel = api.certificateModel {
            if certificateModel.x509Certificate?.checkValidity() ?? false {
                return checkCertificate(api: api, for: dynamicApiProvider).recover { (error) -> Promise<CertificateModel> in
                    switch error {
                    case AppCoordinatorError.certificateInvalid:
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

        let appName: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as! String
        let keyPairDisplayName = "\(appName) for iOS"

        return dynamicApiProvider.request(apiService: .createKeypair(displayName: keyPairDisplayName)).recover({ (error) throws -> Promise<Response> in
            switch error {
            case ApiServiceError.noAuthState:
                return dynamicApiProvider.authorize(presentingViewController: self.navigationController).then({ (_) -> Promise<Response> in
                    return dynamicApiProvider.request(apiService: .createKeypair(displayName: keyPairDisplayName))
                })
            default:
                throw error
            }
        }).then {response -> Promise<CertificateModel> in
                return response.mapResponse()
            }.map { (model) -> CertificateModel in
                self.scheduleCertificateExpirationNotification(for: model, on: api)
                api.certificateModel = model
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
        guard commonNameElements.count == 2 else {
            return Promise<CertificateModel>(error: AppCoordinatorError.certificateCommonNameNotFound)
        }

        guard commonNameElements[0] == "CN" else {
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
        }
    }
    
    func addProvider() {
        // We can not create a static service, so no discovery files are defined. Fall back to adding "another" service.
        if StaticService(type: .instituteAccess) == nil {
            showCustomProviderInPutViewController(for: .other)
        } else {
            showProfilesViewController()
        }
    }

    func showSettingsTableViewController() {
        let settingsTableViewController = storyboard.instantiateViewController(type: SettingsTableViewController.self)
        self.navigationController.pushViewController(settingsTableViewController, animated: true)
        settingsTableViewController.delegate = self
    }

    fileprivate func scheduleCertificateExpirationNotification(for certificate: CertificateModel, on api: Api) {
        UNUserNotificationCenter.current().getNotificationSettings { (settings) in
            guard settings.authorizationStatus == UNAuthorizationStatus.authorized else {
                os_log("Not Authorised", log: Log.general, type: .info)
                return
            }
            guard let expirationDate = certificate.x509Certificate?.notAfter else { return }
            guard let identifier = certificate.uniqueIdentifier else { return }

            let content = UNMutableNotificationContent()
            content.title = NSString.localizedUserNotificationString(forKey: "VPN certificate is expiring!", arguments: nil)
            if let certificateTitle = api.instance?.displayNames?.localizedValue {
                content.body = NSString.localizedUserNotificationString(forKey: "Once expired the certificate for instance %@ needs to be refreshed.",
                                                                        arguments: [certificateTitle])
            }

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

            let trigger = UNCalendarNotificationTrigger(dateMatching: expirationWarningDateComponents, repeats: false)

            // Create the request object.
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request) { (error) in
                if let error = error {
                    os_log("Error occured when scheduling a cert expiration reminder %{public}@", log: Log.general, type: .info, error.localizedDescription)
                }
            }
        }
    }

    fileprivate func refresh(instance: Instance) -> Promise<Void> {
        let provider = MoyaProvider<DynamicInstanceService>()

        let activityData = ActivityData()
        NVActivityIndicatorPresenter.sharedInstance.startAnimating(activityData, nil)
        NVActivityIndicatorPresenter.sharedInstance.setMessage(NSLocalizedString("Fetching instance configuration", comment: ""))

        return provider.request(target: DynamicInstanceService(baseURL: URL(string: instance.baseUri!)!)).then { response -> Promise<InstanceInfoModel> in
            return response.mapResponse()
            }.then { instanceInfoModel -> Promise<Api> in
                return Promise<Api>(resolver: { seal in
                    self.persistentContainer.performBackgroundTask({ (context) in
                        let authServer = AuthServer.upsert(with: instanceInfoModel, on: context)
                        let api = Api.upsert(with: instanceInfoModel, for: instance, on: context)
                        api.authServer = authServer
                        do {
                            try context.save()
                        } catch {
                            seal.reject(error)
                        }

                        seal.fulfill(api)
                    })
                })
            }.then { (api) -> Promise<Void> in
                let api = self.persistentContainer.viewContext.object(with: api.objectID) as! Api //swiftlint:disable:this force_cast
                guard let authorizingDynamicApiProvider = DynamicApiProvider(api: api) else { return .value(()) }
                self.navigationController.popToRootViewController(animated: true)
                return self.refreshProfiles(for: authorizingDynamicApiProvider)
            }.ensure {
                self.providerTableViewController.refresh()
                NVActivityIndicatorPresenter.sharedInstance.stopAnimating(nil)
        }
    }

    private func showSettings() {
        let settingsTableViewController = storyboard.instantiateViewController(type: SettingsTableViewController.self)
        settingsTableViewController.delegate = self
        self.navigationController.pushViewController(settingsTableViewController, animated: true)
    }
    
    private func showConnectionsTableViewController(for instance: Instance) {
        let connectionsTableViewController = storyboard.instantiateViewController(type: ConnectionsTableViewController.self)
        connectionsTableViewController.delegate = self
        connectionsTableViewController.instance = instance
        connectionsTableViewController.viewContext = persistentContainer.viewContext
        self.navigationController.pushViewController(connectionsTableViewController, animated: true)
    }

    private func showProfilesViewController() {
        let profilesViewController = storyboard.instantiateViewController(type: ProfilesViewController.self)

        let fetchRequest = NSFetchRequest<Profile>()
        fetchRequest.entity = Profile.entity()
        fetchRequest.predicate = NSPredicate(format: "api.instance.providerType == %@", ProviderType.secureInternet.rawValue)

        let numberOfSecureInternetProfiles = try? persistentContainer.viewContext.count(for: fetchRequest)
        profilesViewController.showSecureInterNetOption = numberOfSecureInternetProfiles == 0

        profilesViewController.delegate = self
        do {
            try profilesViewController.navigationItem.hidesBackButton = Profile.countInContext(persistentContainer.viewContext) == 0
            self.navigationController.pushViewController(profilesViewController, animated: true)
        } catch {
            self.showError(error)
        }
    }

    private func showCustomProviderInPutViewController(for providerType: ProviderType) {
        let customProviderInputViewController = storyboard.instantiateViewController(type: CustomProviderInPutViewController.self)
        customProviderInputViewController.delegate = self
        self.navigationController.pushViewController(customProviderInputViewController, animated: true)
    }
    
    private func showProviderTableViewController(for providerType: ProviderType) {
        let providerTableViewController = storyboard.instantiateViewController(type: ProviderTableViewController.self)
        providerTableViewController.providerType = providerType
        providerTableViewController.viewContext = persistentContainer.viewContext
        providerTableViewController.delegate = self
        self.navigationController.pushViewController(providerTableViewController, animated: true)

        providerTableViewController.providerType = providerType

        let target: StaticService!
        let sigTarget: StaticService!
        switch providerType {
        case .instituteAccess:
            target = StaticService(type: .instituteAccess)
            sigTarget = StaticService(type: .instituteAccessSignature)
        case .secureInternet:
            target = StaticService(type: .secureInternet)
            sigTarget = StaticService(type: .secureInternetSignature)
        case .unknown, .other:
            return
        }

        guard target != nil && sigTarget != nil else {
            return
        }

        let provider = MoyaProvider<StaticService>()

        provider.request(target: sigTarget).then { response throws -> Promise<Data> in
            if let signature = Data(base64Encoded: response.data) {
                return Promise.value(signature)
            } else {
                throw AppCoordinatorError.sodiumSignatureFetchFailed
            }
        }.then { signature -> Promise<Moya.Response> in
            return provider.request(target: target).then { response throws -> Promise<Moya.Response> in
                guard Sodium().sign.verify(message: Array(response.data), publicKey: Array(StaticService.publicKey), signature: Array(signature)) else {
                    throw AppCoordinatorError.sodiumSignatureVerifyFailed
                }
                return Promise.value(response)
            }
        }.then { response -> Promise<InstancesModel> in

            return response.mapResponse()

        }.then { (instances) -> Promise<Void> in
            var instances = instances
            instances.providerType = providerType
            instances.instances = instances.instances.map({ (instanceModel) -> InstanceModel in
                var instanceModel = instanceModel
                instanceModel.providerType = providerType
                return instanceModel
            })

            let instanceIdentifiers = instances.instances.map { $0.baseUri.absoluteString }

            return Promise(resolver: { (seal) in
                self.persistentContainer.performBackgroundTask({ (context) in
                    let instanceGroupIdentifier = "\(target.baseURL.absoluteString)\(target.path)"
                    let group = try! InstanceGroup.findFirstInContext(context, predicate: NSPredicate(format: "discoveryIdentifier == %@", instanceGroupIdentifier)) ?? InstanceGroup(context: context)//swiftlint:disable:this force_try

                    group.discoveryIdentifier = instanceGroupIdentifier
                    group.authorizationType = instances.authorizationType.rawValue

                    let authServer = AuthServer.upsert(with: instances, on: context)

                    let updatedInstances = group.instances.filter {
                        guard let baseUri = $0.baseUri else { return false }
                        return instanceIdentifiers.contains(baseUri)
                    }

                    updatedInstances.forEach {
                        if let baseUri = $0.baseUri {
                            if let updatedModel = instances.instances.first(where: { (model) -> Bool in
                                return model.baseUri.absoluteString == baseUri
                            }) {
                                $0.providerType = providerType.rawValue
                                $0.authServer = authServer
                                $0.update(with: updatedModel)
                            }
                        }
                    }

                    let updatedInstanceIdentifiers = updatedInstances.compactMap { $0.baseUri}

                    let deletedInstances = group.instances.subtracting(updatedInstances)
                    deletedInstances.forEach {
                        context.delete($0)
                    }

                    let insertedInstancesModels = instances.instances.filter {
                        return !updatedInstanceIdentifiers.contains($0.baseUri.absoluteString)
                    }
                    insertedInstancesModels.forEach { (instanceModel: InstanceModel) in
                        let newInstance = Instance(context: context)
                        group.addToInstances(newInstance)
                        newInstance.group = group
                        newInstance.providerType = providerType.rawValue
                        newInstance.authServer = authServer
                        newInstance.update(with: instanceModel)
                    }

                    context.saveContextToStore({ (result) in
                        switch result {
                        case .success:
                            seal.fulfill(())
                        case .failure(let error):
                            seal.reject(error)
                        }
                    })

                })
            })
        }.recover({ (error) in
            self.showError(error)
        })
    }

    func fetchProfile(for profile: Profile, retry: Bool = false) -> Promise<URL> {
        guard let api = profile.api else {
            precondition(false, "This should never happen")
            return Promise(error: AppCoordinatorError.apiMissing)
        }
        
        guard let dynamicApiProvider = DynamicApiProvider(api: api) else {
            return Promise(error: AppCoordinatorError.apiProviderCreateFailed)
        }

        NVActivityIndicatorPresenter.sharedInstance.setMessage(NSLocalizedString("Loading certificate", comment: ""))

        return loadCertificate(for: api).then { _ -> Promise<Response> in
            NVActivityIndicatorPresenter.sharedInstance.setMessage(NSLocalizedString("Requesting profile config", comment: ""))
            return dynamicApiProvider.request(apiService: .profileConfig(profileId: profile.profileId!))
            }.map { response -> URL in
                guard var ovpnFileContent = String(data: response.data, encoding: .utf8) else {
                    throw AppCoordinatorError.ovpnConfigTemplate
                }
                
                if UserDefaults.standard.forceTcp {
                    let remoteUdpRegex = try! NSRegularExpression(pattern: "remote.*udp", options: [])
                    ovpnFileContent = remoteUdpRegex.stringByReplacingMatches(in: ovpnFileContent, options: [], range: NSRange(location: 0, length: ovpnFileContent.utf16.count), withTemplate: "")
                }
                let remoteTcpRegex = try! NSRegularExpression(pattern: "remote.*", options: [])
                if 0 == remoteTcpRegex.numberOfMatches(in: ovpnFileContent, options: [], range: NSRange(location: 0, length: ovpnFileContent.utf16.count)) {
                    throw AppCoordinatorError.ovpnConfigTemplateNoRemotes
                }

                let insertionIndex = ovpnFileContent.range(of: "</ca>")!.upperBound
                ovpnFileContent.insert(contentsOf: "\n<key>\n\(api.certificateModel!.privateKeyString)\n</key>", at: insertionIndex)
                ovpnFileContent.insert(contentsOf: "\n<cert>\n\(api.certificateModel!.certificateString)\n</cert>", at: insertionIndex)
                ovpnFileContent = ovpnFileContent.replacingOccurrences(of: "auth none\r\n", with: "")
                // TODO: validate response
                try Disk.clear(.temporary)
                // merge profile with keypair
                let filename = "\(profile.displayNames?.localizedValue ?? "")-\(api.instance?.displayNames?.localizedValue ?? "") \(profile.profileId ?? "").ovpn"
                try Disk.save(ovpnFileContent.data(using: .utf8)!, to: .temporary, as: filename)
                let url = try Disk.url(for: filename, in: .temporary)
                return url
            }.recover { (error) throws -> Promise<URL> in
                NVActivityIndicatorPresenter.sharedInstance.stopAnimating(nil)
                switch error {
                case ApiServiceError.tokenRefreshFailed:
                    if retry {
                        self.showError(error)
                        throw error
                    }
                    self.authorizingDynamicApiProvider = dynamicApiProvider
                    return dynamicApiProvider.authorize(presentingViewController: self.navigationController).then { _ -> Promise<URL> in
                        return self.fetchProfile(for: profile, retry: true)
                    }
                case ApiServiceError.noAuthState:
                    if retry {
                        self.showError(error)
                        throw error
                    }
                    self.authorizingDynamicApiProvider = dynamicApiProvider
                    return dynamicApiProvider.authorize(presentingViewController: self.navigationController).then { _ -> Promise<URL> in
                        return self.fetchProfile(for: profile, retry: true)
                    }
                default:
                    self.showError(error)
                    throw error
                }
        }
    }

    func showConnectionViewController(for profile: Profile) {
        let connectionViewController = storyboard.instantiateViewController(type: VPNConnectionViewController.self)
        connectionViewController.providerManagerCoordinator = tunnelProviderManagerCoordinator
        connectionViewController.delegate = self
        connectionViewController.profile = profile
        let navController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(type: UINavigationController.self)
        navController.viewControllers = [connectionViewController]
        self.navigationController.present(navController, animated: true, completion: nil)
    }

    func resumeAuthorizationFlow(url: URL) -> Bool {
        if let authorizingDynamicApiProvider = authorizingDynamicApiProvider {
            guard let authFlow = authorizingDynamicApiProvider.currentAuthorizationFlow else {
                os_log("Resume authrorization attempted, no current authFlow available", log: Log.general, type: .error)
                self.showNoAuthFlowAlert()
                return false
            }
            if authFlow.resumeExternalUserAgentFlow(with: url) == true {
                let authorizationType = authorizingDynamicApiProvider.api.instance?.group?.authorizationTypeEnum ?? .local
                if authorizationType == .distributed {
                    authorizingDynamicApiProvider.api.instance?.group?.distributedAuthorizationApi = authorizingDynamicApiProvider.api
                }
                authorizingDynamicApiProvider.currentAuthorizationFlow = nil
                return true
            }
        }

        return false
    }

    fileprivate func systemMessages(for dynamicApiProvider: DynamicApiProvider) -> Promise<SystemMessages> {
        return dynamicApiProvider.request(apiService: .systemMessages).then { response -> Promise<SystemMessages> in
            return response.mapResponse()
        }
    }

    private func refreshProfiles(for dynamicApiProvider: DynamicApiProvider) -> Promise<Void> {
        let activityData = ActivityData()
        NVActivityIndicatorPresenter.sharedInstance.startAnimating(activityData, nil)
        NVActivityIndicatorPresenter.sharedInstance.setMessage(NSLocalizedString("Refreshing profiles", comment: ""))

        return dynamicApiProvider.request(apiService: .profileList).then { response -> Promise<ProfilesModel> in
            return response.mapResponse()
        }.then { profiles -> Promise<Void> in
            if profiles.profiles.isEmpty {
                self.showNoProfilesAlert()
            }
            return Promise<Void>(resolver: { seal in
                self.persistentContainer.performBackgroundTask({ (context) in
                    if let api = context.object(with: dynamicApiProvider.api.objectID) as? Api {
                        Profile.upsert(with: profiles.profiles, for: api, on: context)
                    }
                    do {
                        try context.save()
                    } catch {
                        seal.reject(error)
                    }
                    
                    seal.fulfill(())
                })
            })
        }.recover { error throws -> Promise<Void> in
            NVActivityIndicatorPresenter.sharedInstance.stopAnimating(nil)

            switch error {
            case ApiServiceError.tokenRefreshFailed:
                self.authorizingDynamicApiProvider = dynamicApiProvider
                return dynamicApiProvider.authorize(presentingViewController: self.navigationController).then({ _ -> Promise<Void> in
                    return self.refreshProfiles(for: dynamicApiProvider)
                }).recover({ error throws in
                    self.showError(error)
                    throw error
                })
            case ApiServiceError.noAuthState:
                self.authorizingDynamicApiProvider = dynamicApiProvider
                return dynamicApiProvider.authorize(presentingViewController: self.navigationController).then({ _ -> Promise<Void> in
                    return self.refreshProfiles(for: dynamicApiProvider)
                }).recover({ error throws in
                    self.showError(error)
                    throw error
                })
            default:
                self.showError(error)
                throw error
            }
        }
    }
}

extension AppCoordinator: SettingsTableViewControllerDelegate {
    func readOnDemand() -> Bool {
        return tunnelProviderManagerCoordinator.currentManager?.isOnDemandEnabled ?? UserDefaults.standard.onDemand
    }
    
    func writeOnDemand(_ onDemand: Bool) {
        UserDefaults.standard.onDemand = onDemand
        tunnelProviderManagerCoordinator.currentManager?.isOnDemandEnabled = onDemand
        tunnelProviderManagerCoordinator.currentManager?.saveToPreferences(completionHandler: nil)
    }
    

}

extension AppCoordinator: ConnectionsTableViewControllerDelegate {
    func connect(profile: Profile) {
        if let currentProfileUuid = profile.uuid, currentProfileUuid.uuidString == UserDefaults.standard.configuredProfileId {
            showConnectionViewController(for: profile)
        } else {
            showAlert(forUnconfigured: profile) { [weak self] in
                guard let self = self else {
                    return
                }
                _ = self.tunnelProviderManagerCoordinator.disconnect()
                _ = self.tunnelProviderManagerCoordinator.configure(profile: profile).then({ (_) -> Promise<Void> in
                    self.providerTableViewController.tableView.reloadData()
                    self.showConnectionViewController(for: profile)
                    return Promise.value(())
                })
            }
        }
    }
}

extension AppCoordinator: ProfilesViewControllerDelegate {
    func profilesViewControllerDidSelectProviderType(profilesViewController: ProfilesViewController, providerType: ProviderType) {
        switch providerType {
        case .instituteAccess, .secureInternet:
            showProviderTableViewController(for: providerType)
        case .other:
            showCustomProviderInPutViewController(for: providerType)
        case .unknown:
            os_log("Unknown provider type chosen", log: Log.general, type: .error)
        }
    }
}

extension AppCoordinator: ProviderTableViewControllerDelegate {
    func addProvider(providerTableViewController: ProviderTableViewController) {
        addProvider()
    }
    
    func addPredefinedProvider(providerTableViewController: ProviderTableViewController) {
        if let providerUrl = Config.shared.predefinedProvider {
            _ = connect(url: providerUrl)
        }
    }
    
    func settings(providerTableViewController: ProviderTableViewController) {
        showSettings()
    }
    
    func didSelectOther(providerType: ProviderType) {
        showCustomProviderInPutViewController(for: providerType)
    }

    func didSelect(instance: Instance, providerTableViewController: ProviderTableViewController) {
        if providerTableViewController.providerType == .unknown {
            let activityData = ActivityData()
            NVActivityIndicatorPresenter.sharedInstance.startAnimating(activityData, nil)
            _ = self.refresh(instance: instance).then({ _ -> Promise<Void> in
                let count = try Profile.countInContext(self.persistentContainer.viewContext, predicate: NSPredicate(format: "api.instance == %@", instance))
                if count > 1 {
                    self.showConnectionsTableViewController(for: instance)
                } else {
                    if let profile = instance.apis?.first?.profiles.first {
                        self.connect(profile: profile)
                    }
                }
                return Promise.value(())
            })
            .recover { (error) in
                self.showError(error)
            }.ensure {
                NVActivityIndicatorPresenter.sharedInstance.stopAnimating(nil)
            }
        } else {
// Move this to pull to refresh?
            self.refresh(instance: instance).recover { (error) in
                let error = error as NSError
                self.showError(error)
            }
        }
    }
    
    func delete(instance: Instance) {
        persistentContainer.performBackgroundTask { (context) in
            if let backgroundProfile = context.object(with: instance.objectID) as? Instance {
                backgroundProfile.apis?.forEach{
                    $0.certificateModel = nil
                    $0.authState = nil
                }
                context.delete(backgroundProfile)
            }
            context.saveContext()
        }
    }

}

extension AppCoordinator: CustomProviderInPutViewControllerDelegate {
    private func createLocalUrl(forImageNamed name: String) throws -> URL {
        let filename = "\(name).png"
        if Disk.exists(filename, in: .applicationSupport) {
            return try Disk.url(for: filename, in: .applicationSupport)
        }

        let image = UIImage(named: name)!
        try Disk.save(image, to: .applicationSupport, as: filename)

        return try Disk.url(for: filename, in: .applicationSupport)
    }

    func connect(url: URL) -> Promise<Void> {
        return Promise<Instance>(resolver: { seal in
            persistentContainer.performBackgroundTask { (context) in
                let instanceGroupIdentifier = url.absoluteString
                let group = try! InstanceGroup.findFirstInContext(context, predicate: NSPredicate(format: "discoveryIdentifier == %@", instanceGroupIdentifier)) ?? InstanceGroup(context: context)//swiftlint:disable:this force_try

                let instance = Instance(context: context)
                instance.providerType = ProviderType.other.rawValue
                instance.baseUri = url.absoluteString
                let displayName = DisplayName(context: context)
                displayName.displayName = url.host
                instance.addToDisplayNames(displayName)
                instance.group = group

                do {
                    try context.save()
                } catch {
                    seal.reject(error)
                }
                seal.fulfill(instance)
            }
        }).then { (instance) -> Promise<Void> in
            let instance = self.persistentContainer.viewContext.object(with: instance.objectID) as! Instance //swiftlint:disable:this force_cast
            return self.refresh(instance: instance)
        }
    }
}

extension AppCoordinator: TunnelProviderManagerCoordinatorDelegate {
    func profileConfig(for profile: Profile) -> Promise<URL> {
        let activityData = ActivityData()
        NVActivityIndicatorPresenter.sharedInstance.startAnimating(activityData, nil)
        
        return fetchProfile(for: profile).ensure {
            NVActivityIndicatorPresenter.sharedInstance.stopAnimating(nil)
        }
    }
}

extension AppCoordinator: VPNConnectionViewControllerDelegate {
    func systemMessages(for profile: Profile) -> Promise<SystemMessages> {
        guard let api = profile.api else {
            precondition(false, "This should never happen")
            return Promise(error: AppCoordinatorError.apiMissing)
        }

        guard let dynamicApiProvider = DynamicApiProvider(api: api) else {
            return Promise(error: AppCoordinatorError.apiProviderCreateFailed)
        }

        return self.systemMessages(for: dynamicApiProvider)
    }
}
