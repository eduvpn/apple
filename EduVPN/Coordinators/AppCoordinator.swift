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

enum AppCoordinatorError: Swift.Error {
    case openVpnSchemeNotAvailable
}

/// The AppCoordinator is our first coordinator
/// In this example the AppCoordinator as a rootViewController
class AppCoordinator: RootViewCoordinator, PersistenceCoordinatorDelegate {

    let persistenceCoordinator: PersistenceCoordinator
    let persistentContainer = NSPersistentContainer(name: "EduVPN")

    let storyboard = UIStoryboard(name: "Main", bundle: nil)

    // MARK: - Properties

    let accessTokenPlugin =  CredentialStorePlugin()

    private var dynamicApiProviders = Set<DynamicApiProvider>()

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
        let navController = UINavigationController()
        return navController
    }()

    // MARK: - Init

    public init(window: UIWindow) {
        self.window = window

        self.persistenceCoordinator = PersistenceCoordinator()
        self.persistenceCoordinator.delegate = self

        self.window.rootViewController = self.navigationController
        self.window.makeKeyAndVisible()

    }

    // MARK: - Functions

    /// Starts the coordinator
    public func start() {
        persistentContainer.loadPersistentStores { [weak self] (persistentStoreDescription, error) in
            if let error = error {
                print("Unable to Load Persistent Store")
                print("\(error), \(error.localizedDescription)")

            } else {
                DispatchQueue.main.async {
                    //start
                    if let connectionsTableViewController = self?.storyboard.instantiateViewController(type: ConnectionsTableViewController.self) {
                        self?.connectionsTableViewController = connectionsTableViewController
                        self?.connectionsTableViewController.delegate = self
                        self?.navigationController.viewControllers = [connectionsTableViewController]
                        if connectionsTableViewController.empty {
                            self?.showProfilesViewController()
                        }
                    }

                    self?.detectPresenceOpenVPN().catch { (_) in
                        self?.showNoOpenVPNAlert()
                    }
                }
            }
        }
    }

    public func showError(_ error: Error) {
        let alert = UIAlertController(title: NSLocalizedString("Error", comment: "Error alert title"), message: error.localizedDescription, preferredStyle: .alert)
        let dismissAction = UIAlertAction(title: "OK", style: .default)
        alert.addAction(dismissAction)
        self.navigationController.present(alert, animated: true)
    }

    func detectPresenceOpenVPN() -> Promise<Void> {
        return Promise(resolvers: { fulfill, reject in
            guard let url = URL(string: "openvpn://") else {
                reject(AppCoordinatorError.openVpnSchemeNotAvailable)
                return
            }
            if UIApplication.shared.canOpenURL(url) {
                fulfill(())
            } else {
                reject(AppCoordinatorError.openVpnSchemeNotAvailable)
            }
        })
    }

    func fetchKeyPair(with dynamicApiProvider: DynamicApiProvider, for displayName: String) -> Promise<Void> {
        return dynamicApiProvider.request(target: ApiService.createKeypair(displayName: displayName)).then { response -> Promise<CertificateModel> in
            return response.mapResponse()
            }.then(execute: { (model) -> Void in
                print(model)
                self.scheduleCertificateExpirationNotification(certificate: model)
            })

//        return Promise(resolvers: { fulfill, reject in
//            //Fetch current keypair
//            // If non-existent or expired, fetch fresh
//            // Otherwise return keypair
//        })
    }

    func showNoOpenVPNAlert() {
        let alertController = UIAlertController(title: NSLocalizedString("OpenVPN Connect app", comment: "No OpenVPN available title"), message: NSLocalizedString("The OpenVPN Connect app is required to use EduVPN.", comment: "No OpenVPN available message"), preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "No OpenVPN available ok button"), style: .default) { _ in
        })
        self.navigationController.present(alertController, animated: true, completion: nil)
    }

    func showSettingsTableViewController() {
        let settingsTableViewController = storyboard.instantiateViewController(type: SettingsTableViewController.self)

        self.navigationController.pushViewController(settingsTableViewController, animated: true)

        settingsTableViewController.delegate = self

    }

    fileprivate func scheduleCertificateExpirationNotification(certificate: CertificateModel) {
        UNUserNotificationCenter.current().getNotificationSettings { (settings) in
            guard settings.authorizationStatus == UNAuthorizationStatus.authorized else {
                print("Not Authorised")
                return
            }

            //        //TODO do this more fine grained
            //        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

            guard let expirationDate = certificate.x509Certificate?.notAfter else { return }

            let content = UNMutableNotificationContent()
            content.title = NSString.localizedUserNotificationString(forKey: "VPN certificate is expiring!", arguments: nil)
            content.body = NSString.localizedUserNotificationString(forKey: "Rise and shine! It's morning time!",
                                                                    arguments: nil)

            #if DEBUG
                guard let expirationWarningDate = NSCalendar.current.date(byAdding: .second, value: 10, to: Date()) else { return }
                let expirationWarningDateComponents = NSCalendar.current.dateComponents(in: NSTimeZone.default, from: expirationWarningDate)
            #else
                guard let expirationWarningDate = NSCalendar.current.date(byAdding: .day, value: -7, to: expirationDate) else { return }
                var expirationWarningDateComponents = NSCalendar.current.dateComponents(in: NSTimeZone.default, from: expirationWarningDate)

                // Configure the trigger for 10am.
                expirationWarningDateComponents.hour = 10
                expirationWarningDateComponents.minute = 0
                expirationWarningDateComponents.second = 0
            #endif

            let trigger = UNCalendarNotificationTrigger(dateMatching: expirationWarningDateComponents, repeats: false)

            // Create the request object.
            let request = UNNotificationRequest(identifier: "MorningAlarm", content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request) { (error) in
                if let error = error {
                    print("Error occured when scheduling a cert expiration reminder \(error)")
                }
            }
        }
    }

    fileprivate func refresh(instance: InstanceModel) -> Promise<Void> {
        //        let provider = DynamicInstanceProvider(baseURL: instance.baseUri)
        let provider = MoyaProvider<DynamicInstanceService>()

        return provider.request(target: DynamicInstanceService(baseURL: instance.baseUri)).then { response -> Promise<InstanceInfoModel> in
            return response.mapResponse()
            }.then { instanceInfoModel -> Void in
                var updatedInstance = instance
                updatedInstance.instanceInfo = instanceInfoModel

                switch instance.providerType {
                case .instituteAccess:
                    if let index = self.persistenceCoordinator.instituteInstancesModel?.instances.index(where: { (instanceModel) -> Bool in
                        return instanceModel.baseUri == updatedInstance.baseUri
                    }) {
                        self.persistenceCoordinator.instituteInstancesModel?.instances[index] = updatedInstance
                    }
                case .secureInternet:
                    if let index = self.persistenceCoordinator.internetInstancesModel?.instances.index(where: { (instanceModel) -> Bool in
                        return instanceModel.baseUri == updatedInstance.baseUri
                    }) {
                        self.persistenceCoordinator.internetInstancesModel?.instances[index] = updatedInstance
                    }
                case .other:
                    if let index = self.persistenceCoordinator.otherInstancesModel?.instances.index(where: { (instanceModel) -> Bool in
                        return instanceModel.baseUri == updatedInstance.baseUri
                    }) {
                        self.persistenceCoordinator.otherInstancesModel?.instances[index] = updatedInstance
                    } else if var otherInstancesModel = self.persistenceCoordinator.otherInstancesModel {
                        otherInstancesModel.instances.append(updatedInstance)
                        self.persistenceCoordinator.otherInstancesModel = otherInstancesModel
                    } else {
                        let otherInstancesModel = InstancesModel(providerType: .other, authorizationType: .local, seq: 0, signedAt: nil, instances: [updatedInstance], authorizationEndpoint: nil, tokenEndpoint: nil)
                        self.persistenceCoordinator.otherInstancesModel = otherInstancesModel
                    }
                case .unknown:
                    precondition(false, "This should not happen")
                    return
                }

                let authorizingDynamicApiProvider = DynamicApiProvider(instanceInfo: instanceInfoModel)
                self.authorizingDynamicApiProvider = authorizingDynamicApiProvider
                _ = authorizingDynamicApiProvider.authorize(presentingViewController: self.navigationController).then {_ in
                        self.navigationController.popToRootViewController(animated: true)
                    }.then { _ in
                    return self.refreshProfiles(for: authorizingDynamicApiProvider)
                }
        }
    }

    fileprivate func showSettings() {
        let settingsTableViewController = storyboard.instantiateViewController(type: SettingsTableViewController.self)
        settingsTableViewController.delegate = self
        self.navigationController.pushViewController(settingsTableViewController, animated: true)
    }

    fileprivate func showProfilesViewController() {
        let profilesViewController = storyboard.instantiateViewController(type: ProfilesViewController.self)
        profilesViewController.delegate = self
        profilesViewController.navigationItem.hidesBackButton = connectionsTableViewController.empty
        self.navigationController.pushViewController(profilesViewController, animated: true)
    }

    fileprivate func showCustomProviderInPutViewController(for providerType: ProviderType) {
        let customProviderInputViewController = storyboard.instantiateViewController(type: CustomProviderInPutViewController.self)
        customProviderInputViewController.delegate = self
        self.navigationController.pushViewController(customProviderInputViewController, animated: true)
    }

    fileprivate func showChooseProviderTableViewController(for providerType: ProviderType) {
        let chooseProviderTableViewController = storyboard.instantiateViewController(type: ChooseProviderTableViewController.self)
        chooseProviderTableViewController.delegate = self
        self.navigationController.pushViewController(chooseProviderTableViewController, animated: true)

        chooseProviderTableViewController.providerType = providerType

        let target: StaticService
        switch providerType {
        case .instituteAccess:
            chooseProviderTableViewController.instances = persistenceCoordinator.instituteInstancesModel
            target = StaticService.instituteAccess
        case .secureInternet:
            chooseProviderTableViewController.instances = persistenceCoordinator.internetInstancesModel
            target = StaticService.secureInternet
        case .unknown, .other:
            return
        }

        let provider = MoyaProvider<StaticService>()
        _ = provider.request(target: target).then { response -> Promise<InstancesModel> in

            return response.mapResponse()
        }.then { (instances) -> Void in
            //TODO verify response with libsodium
            var instances = instances
            instances.providerType = providerType
            instances.instances = instances.instances.map({ (instanceModel) -> InstanceModel in
                var instanceModel = instanceModel
                instanceModel.providerType = providerType
                return instanceModel
            })

            switch providerType {
            case .instituteAccess:
                self.persistenceCoordinator.instituteInstancesModel = instances
            case .secureInternet:
                self.persistenceCoordinator.internetInstancesModel = instances
            case .unknown, .other:
                return
            }

            chooseProviderTableViewController.instances = instances
        }
    }

    func fetchAndTransferProfileToConnectApp(for profile: InstanceProfileModel, on instance: InstanceModel) {
        print(profile)
        guard let instanceInfo = instance.instanceInfo else {
            precondition(false, "This shold never happen")
            return
        }

        let dynamicApiProvider = DynamicApiProvider(instanceInfo: instanceInfo)
        _ = detectPresenceOpenVPN()
            .then { _ -> Promise<Response> in
                return dynamicApiProvider.request(target: .createConfig(displayName: "iOS Created Profile", profileId: profile.profileId))
            }.then { response -> Void in
                // TODO validate response
                let filename = "\(profile.displayName ?? "")-\(instance.displayName ?? "") \(profile.profileId).ovpn"
                try Disk.save(response.data, to: .documents, as: filename)
                let url = try Disk.getURL(for: filename, in: .documents)

                let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                if let currentViewController = self.navigationController.visibleViewController {
                    currentViewController.present(activity, animated: true, completion: {
                        print("Done")
                    })
                }
                return ()
            }.catch { (error) in
                switch error {
                case AppCoordinatorError.openVpnSchemeNotAvailable:
                    self.showNoOpenVPNAlert()
                default:
                    print("Errror: \(error)")
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
                self.dynamicApiProviders.insert(authorizingDynamicApiProvider)
                authorizingDynamicApiProvider.currentAuthorizationFlow = nil
                return true
            }
        }

        return false
    }

    @discardableResult private func refreshProfiles() -> Promise<[ProfilesModel]> {
        // TODO Should this be based on instance info objects?
        let promises = dynamicApiProviders.map({self.refreshProfiles(for: $0)})
        return when(fulfilled: promises)
    }

    @discardableResult private func refreshProfiles(for dynamicApiProvider: DynamicApiProvider) -> Promise<ProfilesModel> {
        return dynamicApiProvider.request(target: .profileList).then { response -> Promise<ProfilesModel> in
            return response.mapResponse()
        }.then { profiles -> Promise<ProfilesModel> in
            self.persistenceCoordinator.instanceInfoProfilesMapping[dynamicApiProvider.instanceInfo] = profiles
            return Promise(value: profiles)
        }
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

    func connect(profile: InstanceProfileModel, on instance: InstanceModel) {
// TODO implement OpenVPN3 client lib        showConnectionViewController(for:profile)
        fetchAndTransferProfileToConnectApp(for: profile, on: instance)
    }

    func delete(profile: InstanceProfileModel, for instanceInfo: InstanceInfoModel) {
        if var profilesModel = persistenceCoordinator.instanceInfoProfilesMapping[instanceInfo] {
            let newProfiles = profilesModel.profiles.filter {$0 != profile}
            if newProfiles.isEmpty {
                persistenceCoordinator.instanceInfoProfilesMapping.removeValue(forKey: instanceInfo)
            } else {
                profilesModel.profiles = newProfiles
                persistenceCoordinator.instanceInfoProfilesMapping[instanceInfo] = profilesModel
            }
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

    func didSelect(instance: InstanceModel, chooseProviderTableViewController: ChooseProviderTableViewController) {
        self.refresh(instance: instance).catch { (error) in
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
    func connect(url: URL) {
        let logoUrl = try? createLocalUrl(forImageNamed: "external_provider")
        let otherModel = InstanceModel(providerType: .other, baseUri: url, displayNames: nil, logoUrls: nil, instanceInfo: nil, displayName: nil, logoUrl: logoUrl)
        refresh(instance: otherModel).catch { (error) in
            self.showError(error)
        }
    }
}

extension AppCoordinator: VPNConnectionViewControllerDelegate {

}
