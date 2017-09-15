//
//  AppCoordinator.swift
//  EduVPN
//
//  Created by Jeroen Leenarts on 08-08-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

import UIKit
import Moya
import PromiseKit

/// The AppCoordinator is our first coordinator
/// In this example the AppCoordinator as a rootViewController
class AppCoordinator: RootViewCoordinator {

    let storyboard = UIStoryboard(name: "Main", bundle: nil)

    // MARK: - Properties

    let accessTokenPlugin =  CredentialStorePlugin()

    private var dynamicApiProviders = Set<DynamicApiProvider>()
    private var profilesSet: Set<ProfilesModel> {
        get {
            if let loadedProfiles: Set<ProfilesModel> = profilesFileManager.loadFromDisk() {
                return Set(loadedProfiles)
            }
            return Set<ProfilesModel>()
        }
        set {
            profilesFileManager.persistToDisk(data: Array(newValue))
        }
    }

    private var authorizingDynamicApiProvider: DynamicApiProvider?
    private let profilesFileManager = ApplicationSupportFileManager(filename: "profiles.dat")
    private let instancesFileManager = ApplicationSupportFileManager(filename: "instances.dat")

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
            return response.mapResponseToInstanceInfo()
            }.then { instanceInfoModel -> Void in
                var instanceInfo = instanceInfoModel
                instanceInfo.instance = instance
                let authorizingDynamicApiProvider = DynamicApiProvider(instanceInfo: instanceInfo)
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

        if let instancesData: [String: Any] = instancesFileManager.loadFromDisk() {
            chooseProviderTableViewController.instances = InstancesModel(json: instancesData, providerType: nil)
        }

        let target: StaticService
        switch providerType {
        case .instituteAccess:
            target = StaticService.instituteAccess
        case .secureInternet:
            target = StaticService.secureInternet
        case .unknown:
            return
        }

        let provider = MoyaProvider<StaticService>()
        _ = provider.request(target: target).then { response -> Promise<InstancesModel> in
            return response.mapResponseToInstances(providerType: providerType)
        }.then { (instances) -> Void in
            //Store response to disk
            self.instancesFileManager.persistToDisk(data: instances.jsonDictionary)
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
            return response.mapResponseToProfiles()
        }.then { profiles -> Promise<ProfilesModel> in
            var profiles = profiles
            profiles.instanceInfo = dynamicApiProvider.instanceInfo
            self.profilesSet.insert(profiles)
            return Promise(value: profiles)
        }
    }

    func profilesUpdated() {
        self.navigationController.viewControllers.forEach {
            if let connectionsViewController = $0 as? ConnectionsTableViewController {
                connectionsViewController.profilesModels = self.profilesSet
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
