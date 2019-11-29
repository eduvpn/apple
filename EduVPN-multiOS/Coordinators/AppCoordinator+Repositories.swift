//
//  AppCoordinator+Repositories.swift
//  eduVPN
//
//  Created by Aleksandr Poddubny on 30/05/2019.
//  Copyright © 2019 SURFNet. All rights reserved.
//

import Foundation
import Moya
import PromiseKit

extension AppCoordinator {
    
    func showActivityIndicator(messageKey: String?, cancellable: Cancellable? = nil) {
        #if os(iOS)
        if activityViewController.presentingViewController == nil {
            rootViewController.present(activityViewController, animated: true)
        }
        activityViewController.activityIndicator.startAnimating()
        #elseif os(macOS)
        mainWindowController.mainViewController.activityIndicatorView.isHidden = false
        mainWindowController.mainViewController.activityIndicator.startAnimation(nil)
        mainWindowController.mainViewController.cancelButton.isHidden = cancellable == nil
        mainWindowController.mainViewController.cancellable = cancellable
        #endif
        setActivityIndicatorMessage(key: messageKey)
    }
    
    func setActivityIndicatorMessage(key messageKey: String?) {
        #if os(iOS)
        activityViewController.infoLabel.text = messageKey.map { NSLocalizedString($0, comment: "") }
        #elseif os(macOS)
        mainWindowController.mainViewController.activityLabel.stringValue = messageKey.map { NSLocalizedString($0, comment: "") } ?? ""
        #endif
    }
    
    func hideActivityIndicator() {
        #if os(iOS)
        if activityViewController.presentingViewController != nil {
            activityViewController.activityIndicator.stopAnimating()
            rootViewController.dismiss(animated: true)
        }
        activityViewController.view.isHidden = false
        #elseif os(macOS)
        mainWindowController.mainViewController.activityIndicatorView.isHidden = true
        mainWindowController.mainViewController.activityIndicator.stopAnimation(nil)
        mainWindowController.mainViewController.cancellable = nil
        #endif
    }
    
    func refresh(instance: Instance) -> Promise<Void> {
        showActivityIndicator(messageKey: "Fetching instance configuration")
        
        return InstancesRepository.shared.refresher.refresh(instance: instance)
            .then { api -> Promise<Void> in
                let api = self.persistentContainer.viewContext.object(with: api.objectID) as! Api //swiftlint:disable:this force_cast
                guard let authorizingDynamicApiProvider = DynamicApiProvider(api: api) else {
                    return .value(())
                }
                
                #if os(iOS)
                self.popToRootViewController()
                #elseif os(macOS)
                self.popToRootViewController(animated: false, completionHandler: {
                    self.dismissViewController()
                })
                #endif
                
                return self.refreshProfiles(for: authorizingDynamicApiProvider)
            }
            .ensure {
                self.providersViewController.refresh()
                NotificationCenter.default.post(name: Notification.Name.InstanceRefreshed, object: self)
                self.hideActivityIndicator()
            }
    }
    
    func fetchProfile(for profile: Profile, retry: Bool = false) -> Promise<[String]> {
        guard let api = profile.api else {
            precondition(false, "This should never happen")
            return Promise(error: AppCoordinatorError.apiMissing)
        }
        
        guard let dynamicApiProvider = DynamicApiProvider(api: api) else {
            return Promise(error: AppCoordinatorError.apiProviderCreateFailed)
        }
        
        setActivityIndicatorMessage(key: "Loading certificate")
        
        return loadCertificate(for: api)
            .then { _ -> Promise<Response> in
                self.setActivityIndicatorMessage(key: "Requesting profile config")
                return dynamicApiProvider.request(apiService: .profileConfig(profileId: profile.profileId!))
            }.map { response -> [String] in
                guard var ovpnFileContent = String(data: response.data, encoding: .utf8) else {
                    throw AppCoordinatorError.ovpnConfigTemplate
                }
                
                ovpnFileContent = self.forceTcp(on: ovpnFileContent)
                try self.validateRemote(on: ovpnFileContent)
                ovpnFileContent = try self.merge(key: api.certificateModel!.privateKeyString, certificate: api.certificateModel!.certificateString, into: ovpnFileContent)
                let lines = ovpnFileContent.components(separatedBy: .newlines).map {
                    $0.trimmingCharacters(in: .whitespacesAndNewlines)
                }.filter {
                    !$0.isEmpty
                }

                return lines
            }.recover { (error) throws -> Promise<[String]> in
                self.hideActivityIndicator()
                
                if retry {
                    self.showError(error)
                    throw error
                }
                
                func retryFetchProfile() -> Promise<[String]> {
                    self.authorizingDynamicApiProvider = dynamicApiProvider
                    #if os(iOS)
                    let authorizeRequest = dynamicApiProvider.authorize(presentingViewController: self.navigationController)
                    self.showActivityIndicator(messageKey: "Authorizing with provider")
                    #elseif os(macOS)
                    let authorizeRequest = dynamicApiProvider.authorize()
                    self.showActivityIndicator(messageKey: "Authorizing with provider", cancellable: authorizeRequest)
                    #endif
                                
                    return authorizeRequest.then { _ -> Promise<[String]> in
                        self.hideActivityIndicator()
                        return self.fetchProfile(for: profile, retry: true)
                    }
                    
                }
                
                if let nsError = error as NSError?,
                    nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorNetworkConnectionLost {
                    return retryFetchProfile()
                }
                
                switch error {
                    
                case ApiServiceError.tokenRefreshFailed, ApiServiceError.noAuthState :
                    return retryFetchProfile()

                default:
                    self.showError(error)
                    throw error
                    
                }
            }
    }
    
    private func refreshProfiles(for dynamicApiProvider: DynamicApiProvider) -> Promise<Void> {
        showActivityIndicator(messageKey: "Refreshing profiles")
        
        return ProfilesRepository.shared.refresher.refresh(for: dynamicApiProvider)
            .recover { error throws -> Promise<Void> in
                self.hideActivityIndicator()
                
                switch error {
                    
                case ApiServiceError.tokenRefreshFailed:
                    self.authorizingDynamicApiProvider = dynamicApiProvider
                    #if os(iOS)
                    let authorizeRequest = dynamicApiProvider.authorize(presentingViewController: self.navigationController)
                    self.showActivityIndicator(messageKey: "Authorizing with provider")
                    #elseif os(macOS)
                    let authorizeRequest = dynamicApiProvider.authorize()
                    self.showActivityIndicator(messageKey: "Authorizing with provider", cancellable: authorizeRequest)
                    #endif
                    
                    return authorizeRequest
                        .then { _ -> Promise<Void> in
                            self.hideActivityIndicator()
                            return self.refreshProfiles(for: dynamicApiProvider)
                        }
                        .recover { error throws in
                            self.hideActivityIndicator()
                            self.showError(error)
                            throw error
                        }
                    
                case ApiServiceError.noAuthState:
                    self.authorizingDynamicApiProvider = dynamicApiProvider
                    #if os(iOS)
                    let authorizeRequest = dynamicApiProvider.authorize(presentingViewController: self.navigationController)
                    self.showActivityIndicator(messageKey: "Authorizing with provider")
                    #elseif os(macOS)
                    let authorizeRequest = dynamicApiProvider.authorize()
                    self.showActivityIndicator(messageKey: "Authorizing with provider", cancellable: authorizeRequest)
                    #endif
                    
                    return authorizeRequest
                        .then { _ -> Promise<Void> in
                            self.hideActivityIndicator()
                            return self.refreshProfiles(for: dynamicApiProvider)
                        }
                        .recover { error throws in
                            self.hideActivityIndicator()
                            self.showError(error)
                            throw error
                        }
                    
                default:
                    self.showError(error)
                    throw error
                    
                }
            }
    }
}

extension Notification.Name {
    static let InstanceRefreshed = Notification.Name("InstanceRefreshed")
}
