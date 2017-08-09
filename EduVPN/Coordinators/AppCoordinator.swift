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

    // MARK: - Properties

    var childCoordinators: [Coordinator] = []

    let instancesFileManager = ApplicationSupportFileManager(filename: "instances.dat")

    var rootViewController: UIViewController {
        return self.navigationController
    }

    let accessTokenPlugin =  CredentialStorePlugin()

    private var currentDynamicApiProvider: DynamicApiProvider?

    /// Window to manage
    let window: UIWindow

    private lazy var navigationController: UINavigationController = {
        let navigationController = UINavigationController()
        return navigationController
    }()

    // MARK: - Init

    public init(window: UIWindow) {
        self.window = window

        self.window.rootViewController = self.rootViewController
        self.window.makeKeyAndVisible()
    }

    // MARK: - Functions

    /// Starts the coordinator
    public func start() {
        self.showConnectionTypeViewController()
    }

    private func showConnectionTypeViewController() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let connectionTypeViewController = storyboard.instantiateViewController(withIdentifier: "connectionTypeViewController") as? ConnectionTypeViewController {
            connectionTypeViewController.delegate = self
            self.navigationController.viewControllers = [connectionTypeViewController]
        }
    }

    fileprivate func showChooseProviderTableViewController() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let chooseProviderTableViewController = storyboard.instantiateViewController(withIdentifier: "chooseProviderTableViewController") as? ChooseProviderTableViewController {
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
    }

    fileprivate func authenticate(instance: InstanceModel) {

    }

    func resumeAuthorizationFlow(url: URL) -> Bool {
        if currentDynamicApiProvider?.currentAuthorizationFlow?.resumeAuthorizationFlow(with: url) == true {
            currentDynamicApiProvider?.currentAuthorizationFlow = nil

            return true
        }

        return false
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
                self.currentDynamicApiProvider?.authorize(presentingViewController: self.rootViewController)
            }
        }
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

    fileprivate func connect(instance: InstanceModel) {

    }
}

extension AppCoordinator: ConnectionTypeViewControllerDelegate {
    func connectionTypeViewControllerDidSelectProviderType(connectionTypeViewController: ConnectionTypeViewController, providerType: ProviderType) {
        switch providerType {
        case .instituteAccess:
            showChooseProviderTableViewController()
        case .secureInternet:
            print("...implement me...")
        }
    }
}

extension AppCoordinator: ChooseProviderTableViewControllerDelegate {
    func didSelect(instance: InstanceModel, chooseProviderTableViewController: ChooseProviderTableViewController) {
        self.refresh(instance: instance)
    }
}
