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

#if os(iOS)
import NVActivityIndicatorView
#endif

extension AppCoordinator {
    
    private func showActivityIndicator(messageKey: String) {
        #if os(iOS)
        NVActivityIndicatorPresenter.sharedInstance.startAnimating(ActivityData(), nil)
        #elseif os(macOS)
        mainWindowController.mainViewController.activityIndicatorView.isHidden = false
        mainWindowController.mainViewController.activityIndicator.startAnimation(nil)
        #endif
        setActivityIndicatorMessage(key: messageKey)
    }
    
    private func setActivityIndicatorMessage(key messageKey: String) {
        #if os(iOS)
        NVActivityIndicatorPresenter.sharedInstance.setMessage(NSLocalizedString(messageKey, comment: ""))
        #elseif os(macOS)
        mainWindowController.mainViewController.activityLabel.stringValue = NSLocalizedString(messageKey, comment: "")
        #endif
    }
    
    private func hideActivityIndicator() {
        #if os(iOS)
        NVActivityIndicatorPresenter.sharedInstance.stopAnimating(nil)
        #elseif os(macOS)
        mainWindowController.mainViewController.activityIndicatorView.isHidden = true
        mainWindowController.mainViewController.activityIndicator.stopAnimation(nil)
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
                
                self.hideActivityIndicator()
            }
    }
    
    func fetchProfile(for profile: Profile, retry: Bool = false) -> Promise<URL> {
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
            }
            .map { response -> URL in
                guard var ovpnFileContent = String(data: response.data, encoding: .utf8) else {
                    throw AppCoordinatorError.ovpnConfigTemplate
                }
                
                ovpnFileContent = self.forceTcp(on: ovpnFileContent)
                try self.validateRemote(on: ovpnFileContent)
                ovpnFileContent = self.merge(key: api.certificateModel!.privateKeyString, certificate: api.certificateModel!.certificateString, into: ovpnFileContent)
                
                let filename = "\(profile.displayNames?.localizedValue ?? "")-\(api.instance?.displayNames?.localizedValue ?? "") \(profile.profileId ?? "").ovpn"
                return try self.saveToOvpnFile(content: ovpnFileContent, to: filename)
            }
            .recover { error throws -> Promise<URL> in
                self.hideActivityIndicator()
                
                if retry {
                    self.showError(error)
                    throw error
                }
                
                func retryFetchProile() -> Promise<URL> {
                    self.authorizingDynamicApiProvider = dynamicApiProvider
                    #if os(iOS)
                    let authorizeRequest = dynamicApiProvider.authorize(presentingViewController: self.navigationController)
                    #elseif os(macOS)
                    let authorizeRequest = dynamicApiProvider.authorize()
                    #endif
                    
                    self.showActivityIndicator(messageKey: "Authorizing with provider")
                                
                    return authorizeRequest.then { _ -> Promise<URL> in
                        self.hideActivityIndicator()
                        return self.fetchProfile(for: profile, retry: true)
                    }
                    
                }
                
                if let nsError = error as NSError?,
                    nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorNetworkConnectionLost {
                    return retryFetchProile()
                }
                
                switch error {
                    
                case ApiServiceError.tokenRefreshFailed, ApiServiceError.noAuthState :
                    return retryFetchProile()
                    
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
                    #elseif os(macOS)
                    let authorizeRequest = dynamicApiProvider.authorize()
                    #endif
                    
                    self.showActivityIndicator(messageKey: "Authorizing with provider")
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
                    #elseif os(macOS)
                    let authorizeRequest = dynamicApiProvider.authorize()
                    #endif
                    
                    self.showActivityIndicator(messageKey: "Authorizing with provider")
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
