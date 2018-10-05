//
//  AppCoordinator.swift
//  EduVPN
//
//  Created by Jeroen Leenarts on 08-08-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

import UIKit
import UserNotifications

import Moya
import Disk
import PromiseKit

import CoreData
import BNRCoreDataStack

import AppAuth

import NVActivityIndicatorView

// swiftlint:disable type_body_length
// swiftlint:disable file_length
// swiftlint:disable function_body_length

extension UINavigationController: Identifyable {}

enum AppCoordinatorError: Swift.Error {
    case openVpnSchemeNotAvailable
    case certificateInvalid
    case certificateNil
    case certificateCommonNameNotFound
    case certificateStatusUnknown
    case apiProviderCreateFailed
}

class AppCoordinator: RootViewCoordinator {

    let persistentContainer = NSPersistentContainer(name: "EduVPN")
    let storyboard = UIStoryboard(name: "Main", bundle: nil)

    // MARK: - Properties

    let accessTokenPlugin =  CredentialStorePlugin()

    private var currentDocumentInteractionController: UIDocumentInteractionController?

    private var authorizingDynamicApiProvider: DynamicApiProvider?

    var childCoordinators: [Coordinator] = []

    var rootViewController: UIViewController {
        return self.connectionsTableViewController
    }

    var connectionsTableViewController: ConnectionsTableViewController!

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
        persistentContainer.viewContext.automaticallyMergesChangesFromParent = true
        persistentContainer.loadPersistentStores { [weak self] (_, error) in
            if let error = error {
                print("Unable to Load Persistent Store. \(error), \(error.localizedDescription)")

            } else {
                DispatchQueue.main.async {
                    //start
                    if let connectionsTableViewController = self?.storyboard.instantiateViewController(type: ConnectionsTableViewController.self) {
                        self?.connectionsTableViewController = connectionsTableViewController
                        self?.connectionsTableViewController.viewContext = self?.persistentContainer.viewContext
                        self?.connectionsTableViewController.delegate = self
                        self?.navigationController.viewControllers = [connectionsTableViewController]
                        do {
                            if let context = self?.persistentContainer.viewContext, try Profile.countInContext(context) == 0 {
                                self?.showProfilesViewController()
                            }
                        } catch {
                            self?.showError(error)
                        }
                    }

                    self?.detectPresenceOpenVPN().recover { (_) in
                        self?.showNoOpenVPNAlert()
                    }
                }
            }
        }
    }

    func detectPresenceOpenVPN() -> Promise<Void> {
        #if DEBUG
            return .value(())
        #else
            return Promise(resolver: { seal in
                guard let url = URL(string: "openvpn://") else {
                    seal.reject(AppCoordinatorError.openVpnSchemeNotAvailable)
                    return
                }
                if UIApplication.shared.canOpenURL(url) {
                    seal.fulfill(())
                } else {
                    seal.reject(AppCoordinatorError.openVpnSchemeNotAvailable)
                }
            })
        #endif
    }

    func loadCertificate(for api: Api) -> Promise<CertificateModel> {
        guard let dynamicApiProvider = DynamicApiProvider(api: api) else { return Promise.init(error: AppCoordinatorError.apiProviderCreateFailed) }

        if let certificateModel = api.certificateModel {
            if certificateModel.x509Certificate?.checkValidity() ?? false {
                return checkCertificate(api: api, for: dynamicApiProvider)
            } else {
                api.certificateModel = nil
            }
        }

        return dynamicApiProvider.request(apiService: .createKeypair(displayName: "eduVPN for iOS")).recover({ (error) throws -> Promise<Response> in
            switch error {
            case ApiServiceError.noAuthState:
                return dynamicApiProvider.authorize(presentingViewController: self.navigationController).then({ (_) -> Promise<Response> in
                    return dynamicApiProvider.request(apiService: .createKeypair(displayName: "eduVPN for iOS"))
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

    func showSettingsTableViewController() {
        let settingsTableViewController = storyboard.instantiateViewController(type: SettingsTableViewController.self)
        self.navigationController.pushViewController(settingsTableViewController, animated: true)
        settingsTableViewController.delegate = self
    }

    fileprivate func scheduleCertificateExpirationNotification(for certificate: CertificateModel, on api: Api) {
        UNUserNotificationCenter.current().getNotificationSettings { (settings) in
            guard settings.authorizationStatus == UNAuthorizationStatus.authorized else {
                print("Not Authorised")
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
                    print("Error occured when scheduling a cert expiration reminder \(error)")
                }
            }
        }
    }

    fileprivate func refresh(instance: Instance) -> Promise<Void> {
        //        let provider = DynamicInstanceProvider(baseURL: instance.baseUri)
        let provider = MoyaProvider<DynamicInstanceService>()

        let activityData = ActivityData()
        NVActivityIndicatorPresenter.sharedInstance.startAnimating(activityData)
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
                NVActivityIndicatorPresenter.sharedInstance.setMessage(NSLocalizedString("Refreshing profiles", comment: ""))
                return self.refreshProfiles(for: authorizingDynamicApiProvider)
            }.recover { (error) in
                self.showError(error)
            }.ensure {
                NVActivityIndicatorPresenter.sharedInstance.stopAnimating()
        }
    }

    private func showSettings() {
        let settingsTableViewController = storyboard.instantiateViewController(type: SettingsTableViewController.self)
        settingsTableViewController.delegate = self
        self.navigationController.pushViewController(settingsTableViewController, animated: true)
    }

    private func showProfilesViewController() {
        let profilesViewController = storyboard.instantiateViewController(type: ProfilesViewController.self)
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

    private func showChooseProviderTableViewController(for providerType: ProviderType) {
        let chooseProviderTableViewController = storyboard.instantiateViewController(type: ChooseProviderTableViewController.self)
        chooseProviderTableViewController.providerType = providerType
        chooseProviderTableViewController.viewContext = persistentContainer.viewContext
        chooseProviderTableViewController.delegate = self
        self.navigationController.pushViewController(chooseProviderTableViewController, animated: true)

        chooseProviderTableViewController.providerType = providerType

        let target: StaticService
        switch providerType {
        case .instituteAccess:
            target = StaticService.instituteAccess
        case .secureInternet:
            target = StaticService.secureInternet
        case .unknown, .other:
            return
        }

        let provider = MoyaProvider<StaticService>()
        _ = provider.request(target: target).then { response -> Promise<InstancesModel> in

            return response.mapResponse()
        }.then { (instances) -> Promise<Void> in
            //TODO verify response with libsodium
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
        }
    }

    func fetchAndTransferProfileToConnectApp(for profile: Profile, sourceView: UIView?) {
        guard let api = profile.api else {
            precondition(false, "This should never happen")
            return
        }

        let activityData = ActivityData()
        NVActivityIndicatorPresenter.sharedInstance.startAnimating(activityData)

        guard let dynamicApiProvider = DynamicApiProvider(api: api) else { return }

        _ = detectPresenceOpenVPN().then { _ -> Promise<CertificateModel> in
            NVActivityIndicatorPresenter.sharedInstance.setMessage(NSLocalizedString("Loading certificate", comment: ""))
            return self.loadCertificate(for: api)
        }.then { _ -> Promise<Response> in
            NVActivityIndicatorPresenter.sharedInstance.setMessage(NSLocalizedString("Requesting profile config", comment: ""))
                return dynamicApiProvider.request(apiService: .profileConfig(profileId: profile.profileId!))
            }.map { response -> Void in
                var ovpnFileContent = String(data: response.data, encoding: .utf8)
                let insertionIndex = ovpnFileContent!.range(of: "</ca>")!.upperBound
                ovpnFileContent?.insert(contentsOf: "\n<key>\n\(api.certificateModel!.privateKeyString)\n</key>", at: insertionIndex)
                ovpnFileContent?.insert(contentsOf: "\n<cert>\n\(api.certificateModel!.certificateString)\n</cert>", at: insertionIndex)
                // TODO validate response
                try Disk.clear(.temporary)
                // merge profile with keypair
                let filename = "\(profile.displayNames?.localizedValue ?? "")-\(api.instance?.displayNames?.localizedValue ?? "") \(profile.profileId ?? "").ovpn"
                try Disk.save(ovpnFileContent!.data(using: .utf8)!, to: .temporary, as: filename)
                let url = try Disk.getURL(for: filename, in: .temporary)

                let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                if let currentViewController = self.navigationController.visibleViewController {
                    if let presentationController = activity.presentationController as? UIPopoverPresentationController {
                        presentationController.sourceView = sourceView ?? self.navigationController.navigationBar
                        presentationController.sourceRect = sourceView?.frame ?? self.navigationController.navigationBar.frame
                        presentationController.permittedArrowDirections = [.any]
                    }
                    currentViewController.present(activity, animated: true)
                }
                return ()
            }.ensure {
                NVActivityIndicatorPresenter.sharedInstance.stopAnimating()
            }.recover { (error) in
                switch error {
                case ApiServiceError.tokenRefreshFailed:
                    self.authorizingDynamicApiProvider = dynamicApiProvider
                    _ = dynamicApiProvider.authorize(presentingViewController: self.navigationController)
                case AppCoordinatorError.openVpnSchemeNotAvailable:
                    self.showNoOpenVPNAlert()
                default:
                    self.showError(error)
                }
            }
    }

    func showConnectionViewController(for profile: InstanceProfileModel, on instance: InstanceModel) {
        let connectionViewController = storyboard.instantiateViewController(type: VPNConnectionViewController.self)
        connectionViewController.delegate = self
        self.navigationController.pushViewController(connectionViewController, animated: true)
    }

    func resumeAuthorizationFlow(url: URL) -> Bool {
        if let authorizingDynamicApiProvider = authorizingDynamicApiProvider {
            if authorizingDynamicApiProvider.currentAuthorizationFlow?.resumeAuthorizationFlow(with: url) == true {
                let authorizationType = authorizingDynamicApiProvider.api.instance?.group?.authorizationTypeEnum ?? .local
                if authorizationType == .distributed {
                    authorizingDynamicApiProvider.api.instance?.group?.federatedAuthorizationApi = authorizingDynamicApiProvider.api
                }
                authorizingDynamicApiProvider.currentAuthorizationFlow = nil
                return true
            }
        }

        return false
    }

    @discardableResult private func refreshProfiles(for dynamicApiProvider: DynamicApiProvider) -> Promise<Void> {
        return dynamicApiProvider.request(apiService: .profileList).then { response -> Promise<ProfilesModel> in
            return response.mapResponse()
        }.map { profiles -> Void in
            if profiles.profiles.isEmpty {
                self.showNoProfilesAlert()
            }
            self.persistentContainer.performBackgroundTask({ (context) in
                let api = context.object(with: dynamicApiProvider.api.objectID) as? Api
                api?.profiles.forEach({ (profile) in
                    context.delete(profile)
                })

                profiles.profiles.forEach {
                    let profile = Profile(context: context)
                    profile.api = api
                    profile.update(with: $0)
                }
                context.saveContext()
            })
        }.recover({ (error) in
            switch error {
            case ApiServiceError.tokenRefreshFailed:
                self.authorizingDynamicApiProvider = dynamicApiProvider
                _ = dynamicApiProvider.authorize(presentingViewController: self.navigationController)
            case ApiServiceError.noAuthState:
                self.authorizingDynamicApiProvider = dynamicApiProvider
                _ = dynamicApiProvider.authorize(presentingViewController: self.navigationController).then({ _ -> Promise<Void> in
                    self.refreshProfiles(for: dynamicApiProvider)
                })
            default:
                self.showError(error)
            }
        })
    }
}

extension AppCoordinator: SettingsTableViewControllerDelegate {

}

extension AppCoordinator: ConnectionsTableViewControllerDelegate {
    func settings(connectionsTableViewController: ConnectionsTableViewController) {
        showSettings()
    }

    func addProvider(connectionsTableViewController: ConnectionsTableViewController) {
        showProfilesViewController()
    }

    func connect(profile: Profile, sourceView: UIView?) {
        //TODO showConnectionViewController(for:profile)
        fetchAndTransferProfileToConnectApp(for: profile, sourceView: sourceView)
    }

    func delete(profile: Profile) {
        persistentContainer.performBackgroundTask { (context) in
            let backgroundProfile = context.object(with: profile.objectID)
            context.delete(backgroundProfile)
            context.saveContext()
        }
    }
}

extension AppCoordinator: ProfilesViewControllerDelegate {
    func profilesViewControllerDidSelectProviderType(profilesViewController: ProfilesViewController, providerType: ProviderType) {
        switch providerType {
        case .instituteAccess, .secureInternet:
            showChooseProviderTableViewController(for: providerType)
        case .other:
            showCustomProviderInPutViewController(for: providerType)
        case .unknown:
            print("Unknown provider type chosen")
        }
    }
}

extension AppCoordinator: ChooseProviderTableViewControllerDelegate {
    func didSelectOther(providerType: ProviderType) {
        showCustomProviderInPutViewController(for: providerType)
    }

    func didSelect(instance: Instance, chooseProviderTableViewController: ChooseProviderTableViewController) {
        self.refresh(instance: instance).recover { (error) in
            let error = error as NSError
            if error.domain == OIDGeneralErrorDomain && (error.code == OIDErrorCode.programCanceledAuthorizationFlow.rawValue || error.code == OIDErrorCode.userCanceledAuthorizationFlow.rawValue) {
                // It is a OIDErrorCodeProgramCanceledAuthorizationFlow, which means the user cancelled.
                return
            }
            self.showError(error)
        }
    }
}

extension AppCoordinator: CustomProviderInPutViewControllerDelegate {
    private func createLocalUrl(forImageNamed name: String) throws -> URL {
        let filename = "\(name).png"
        if Disk.exists(filename, in: .applicationSupport) {
            return try Disk.getURL(for: filename, in: .applicationSupport)
        }

        let image = UIImage(named: name)!
        try Disk.save(image, to: .applicationSupport, as: filename)

        return try Disk.getURL(for: filename, in: .applicationSupport)
    }

    func connect(url: URL) -> Promise<Void> {
        return Promise<Instance>(resolver: { seal in
            persistentContainer.performBackgroundTask { (context) in
                let instanceGroupIdentifier = url.absoluteString
                let group = try! InstanceGroup.findFirstInContext(context, predicate: NSPredicate(format: "discoveryIdentifier == %@", instanceGroupIdentifier)) ?? InstanceGroup(context: context)//swiftlint:disable:this force_try

                let instance = Instance(context: context)
                instance.providerType = ProviderType.other.rawValue
                instance.baseUri = url.absoluteString
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

extension AppCoordinator: VPNConnectionViewControllerDelegate {

}
