//
//  AppCoordinator.swift
//  EduVPN
//
//  Created by Jeroen Leenarts on 08-08-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

import UIKit
import Moya
import Disk
import PromiseKit

enum AppCoordinatorError: Swift.Error {
    case openVpnSchemeNotAvailable
}

/// The AppCoordinator is our first coordinator
/// In this example the AppCoordinator as a rootViewController
class AppCoordinator: RootViewCoordinator {

    let storyboard = UIStoryboard(name: "Main", bundle: nil)

    // MARK: - Properties

    let accessTokenPlugin =  CredentialStorePlugin()

    private var dynamicApiProviders = Set<DynamicApiProvider>()

    private var currentDocumentInteractionController: UIDocumentInteractionController?

    private var instanceInfoProfilesMapping: [InstanceInfoModel: ProfilesModel] {
        get {
            do {
                return try Disk.retrieve("instanceInfoProfilesMapping.json", from: .documents, as: [InstanceInfoModel: ProfilesModel].self)
            } catch {
                //TODO handle error
                print(error)
                return [InstanceInfoModel: ProfilesModel]()
            }
        }
        set {
            do {
                try Disk.save(newValue, to: .documents, as: "instanceInfoProfilesMapping.json")
            } catch {
                //TODO handle error
                print(error)
            }
        }
    }

    private var internetInstancesModel: InstancesModel? {
        get {
            do {
                return try Disk.retrieve("internet-instances.json", from: .documents, as: InstancesModel.self)
            } catch {
                //TODO handle error
                print(error)
                return nil
            }
        }
        set {
            do {
                try Disk.save(newValue, to: .documents, as: "internet-instances.json")
                self.connectionsTableViewController.internetInstancesModel = newValue
            } catch {
                //TODO handle error
                print(error)
            }
        }
    }

    private var instituteInstancesModel: InstancesModel? {
        get {
            do {
                return try Disk.retrieve("institute-instances.json", from: .documents, as: InstancesModel.self)
            } catch {
                //TODO handle error
                print(error)
                return nil
            }
        }
        set {
            do {
                try Disk.save(newValue, to: .documents, as: "institute-instances.json")
                self.connectionsTableViewController.instituteInstancesModel = newValue
            } catch {
                //TODO handle error
                print(error)
            }
        }
    }

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

        self.window.rootViewController = self.navigationController
        self.window.makeKeyAndVisible()
    }

    // MARK: - Functions

    /// Starts the coordinator
    public func start() {
        //start
        connectionsTableViewController = storyboard.instantiateViewController(type: ConnectionsTableViewController.self)
        connectionsTableViewController.internetInstancesModel = internetInstancesModel
        connectionsTableViewController.instituteInstancesModel = instituteInstancesModel
        connectionsTableViewController.instanceInfoProfilesMapping = instanceInfoProfilesMapping
        connectionsTableViewController.delegate = self
        self.navigationController.viewControllers = [connectionsTableViewController]

        if connectionsTableViewController.empty {
            showProfilesViewController()
        }

        detectPresenceOpenVPN().catch { (_) in
            self.showNoOpenVPNAlert()
        }
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

    func showNoOpenVPNAlert() {
        let alertController = UIAlertController(title: NSLocalizedString("OpenVPN Connect app", comment: "No OpenVPN available title"), message: NSLocalizedString("De OpenVPN Connect app is vereist om EduVPN te gebruiken.", comment: "No OpenVPN available message"), preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "No OpenVPN available ok button"), style: .default) { _ in
        })
        self.navigationController.present(alertController, animated: true, completion: nil)
    }

    func showSettingsTableViewController() {
        let settingsTableViewController = storyboard.instantiateViewController(type: SettingsTableViewController.self)

        self.navigationController.pushViewController(settingsTableViewController, animated: true)

        settingsTableViewController.delegate = self

    }

    fileprivate func refresh(instance: InstanceModel) {
        //        let provider = DynamicInstanceProvider(baseURL: instance.baseUri)
        let provider = MoyaProvider<DynamicInstanceService>()

        _ = provider.request(target: DynamicInstanceService(baseURL: instance.baseUri)).then { response -> Promise<InstanceInfoModel> in
            return response.mapResponse()
            }.then { instanceInfoModel -> Void in
                var updatedInstance = instance
                updatedInstance.instanceInfo = instanceInfoModel

                switch instance.providerType {
                case .instituteAccess:
                    if let index = self.instituteInstancesModel?.instances.index(where: { (instanceModel) -> Bool in
                        return instanceModel.baseUri == updatedInstance.baseUri
                    }) {
                        self.instituteInstancesModel?.instances[index] = updatedInstance
                    }
                case .secureInternet:
                    if let index = self.internetInstancesModel?.instances.index(where: { (instanceModel) -> Bool in
                        return instanceModel.baseUri == updatedInstance.baseUri
                    }) {
                        self.internetInstancesModel?.instances[index] = updatedInstance
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
                    return self.refreshProfiles(for: authorizingDynamicApiProvider).then {_ in
                        self.profilesUpdated()
                    }
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
            chooseProviderTableViewController.instances = instituteInstancesModel
            target = StaticService.instituteAccess
        case .secureInternet:
            chooseProviderTableViewController.instances = internetInstancesModel
            target = StaticService.secureInternet
        case .unknown:
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
                self.instituteInstancesModel = instances
            case .secureInternet:
                self.internetInstancesModel = instances
            case .unknown:
                return
            }

            chooseProviderTableViewController.instances = instances
        }
    }

    func fetchAndTransferProfileToConnectApp(for profile: ProfileModel, on instance: InstanceModel) {
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
                try Disk.save(response.data, to: .documents, as: "new_profile.ovpn")
                let url = try Disk.getURL(for: "new_profile.ovpn", in: .documents)

                self.currentDocumentInteractionController = UIDocumentInteractionController(url: url)
                if let currentViewController = self.navigationController.visibleViewController {
                    self.currentDocumentInteractionController?.presentOpenInMenu(from: currentViewController.view.frame, in: currentViewController.view, animated: true)
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

    func showConnectionViewController(for profile: ProfileModel, on instance: InstanceModel) {
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
            self.instanceInfoProfilesMapping[dynamicApiProvider.instanceInfo] = profiles
            return Promise(value: profiles)
        }
    }

    func profilesUpdated() {
        self.navigationController.viewControllers.forEach {
            if let connectionsViewController = $0 as? ConnectionsTableViewController {
                connectionsViewController.instanceInfoProfilesMapping = self.instanceInfoProfilesMapping
            }
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

    func connect(profile: ProfileModel, on instance: InstanceModel) {
// TODO implement OpenVPN3 client lib        showConnectionViewController(for:profile)
        fetchAndTransferProfileToConnectApp(for: profile, on: instance)
    }
}

extension AppCoordinator: ProfilesViewControllerDelegate {
    func profilesViewControllerDidSelectProviderType(profilesViewController: ProfilesViewController, providerType: ProviderType) {
        switch providerType {
        case .instituteAccess, .secureInternet:
            showChooseProviderTableViewController(for: providerType)
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
        self.refresh(instance: instance)
    }
}

extension AppCoordinator: CustomProviderInPutViewControllerDelegate {

}

extension AppCoordinator: VPNConnectionViewControllerDelegate {

}
