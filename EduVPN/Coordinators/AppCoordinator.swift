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

    private var currentDynamicApiProvider: DynamicApiProvider?
    let instancesFileManager = ApplicationSupportFileManager(filename: "instances.dat")

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

        _ = provider.request(target: DynamicInstanceService(baseURL: instance.baseUri)).then { response -> InstanceInfoModel? in
            return try response.mapResponseToInstanceInfo()
            }.then { instanceInfoModel -> Void in
                if let instanceInfo = instanceInfoModel {
                    //TODO: plugins: [accessTokenPlugin]
                    self.currentDynamicApiProvider = DynamicApiProvider(instanceInfo: instanceInfo)
                    self.currentDynamicApiProvider?.authorize(presentingViewController: self.navigationController)
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

    fileprivate func showChooseProviderTableViewController() {
        let chooseProviderTableViewController = storyboard.instantiateViewController(type:ChooseProviderTableViewController.self)
        chooseProviderTableViewController.delegate = self
        self.navigationController.pushViewController(chooseProviderTableViewController, animated: true)

        if let instancesData: [String: Any] = instancesFileManager.loadFromDisk() {
            chooseProviderTableViewController.instances = InstancesModel(json: instancesData)
        }

        let provider = MoyaProvider<StaticService>()
        _ = provider.request(target: .instances).then { response -> Void in

            if let instances = try response.mapResponseToInstances() {
                //Store response to disk
                self.instancesFileManager.persistToDisk(data: instances.jsonDictionary)
                chooseProviderTableViewController.instances = instances
            }
        }
    }

    func resumeAuthorizationFlow(url: URL) -> Bool {
        if currentDynamicApiProvider?.currentAuthorizationFlow?.resumeAuthorizationFlow(with: url) == true {
            currentDynamicApiProvider?.currentAuthorizationFlow = nil

            return true
        }

        return false
    }

    fileprivate func fetchUserMessage() -> Promise<Response>? {
        return currentDynamicApiProvider?.request(target: .userMessages).then { response -> Response in
            print(response)
            return response
        }
    }

    fileprivate func fetchSystemMessage() -> Promise<Response>? {
        return currentDynamicApiProvider?.request(target: .systemMessages).then { response -> Response in
            print(response)
            return response
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
        case .instituteAccess:
            showChooseProviderTableViewController()
        case .secureInternet:
            print("...implement me...")
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
