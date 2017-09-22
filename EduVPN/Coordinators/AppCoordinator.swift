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

/// The AppCoordinator is our first coordinator
/// In this example the AppCoordinator as a rootViewController
class AppCoordinator: RootViewCoordinator {

    let storyboard = UIStoryboard(name: "Main", bundle: nil)

    // MARK: - Properties

    let accessTokenPlugin =  CredentialStorePlugin()

    private var dynamicApiProviders = Set<DynamicApiProvider>()

    private var instanceInfoProfilesMapping: [InstanceInfoModel:ProfilesModel] {
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
    }

    fileprivate func authenticate(instance: InstanceModel) {

    }

    fileprivate func connect(instance: InstanceModel) {

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
                updatedInstance.instanceInfo = instanceInfoModel //TODO: assign value back to storage.

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
                    return self.refreshProfile(for: authorizingDynamicApiProvider).then {_ in
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
        self.navigationController.pushViewController(profilesViewController, animated: true)
    }

    fileprivate func showChooseProviderTableViewController(for providerType: ProviderType) {
        let chooseProviderTableViewController = storyboard.instantiateViewController(type:ChooseProviderTableViewController.self)
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

    @discardableResult fileprivate func refreshProfiles() -> Promise<[ProfilesModel]> {
        let promises = dynamicApiProviders.map({self.refreshProfile(for: $0)})
        return when(fulfilled: promises)
    }

    @discardableResult fileprivate func refreshProfile(for dynamicApiProvider: DynamicApiProvider) -> Promise<ProfilesModel> {
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
    func didSelect(instance: InstanceModel, chooseProviderTableViewController: ChooseProviderTableViewController) {
        self.refresh(instance: instance)
    }
}
