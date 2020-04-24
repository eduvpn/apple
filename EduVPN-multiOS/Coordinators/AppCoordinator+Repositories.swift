//
//  AppCoordinator+Repositories.swift
//  eduVPN
//

import Foundation
import Moya
import PromiseKit

extension AppCoordinator {
    
    func showActivityIndicator(messageKey: String?, cancellable: Cancellable? = nil) {
        #if os(iOS)
        if activityViewController.presentingViewController == nil {
            rootViewController.navigationController?.present(activityViewController, animated: true)
        }
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
        let infoString = messageKey.map { NSLocalizedString($0, comment: "") } ?? ""
        activityViewController.activityViewModel = ActivityViewModel(infoString: infoString)
        #elseif os(macOS)
        mainWindowController.mainViewController.activityLabel.stringValue = messageKey.map { NSLocalizedString($0, comment: "") } ?? ""
        #endif
    }
    
    func hideActivityIndicator() -> Guarantee<Void> {
        #if os(iOS)
        activityViewController.view.isHidden = true
        if activityViewController.presentingViewController != nil {
            return Guarantee(resolver: { seal in
                rootViewController.navigationController?.dismiss(animated: true, completion: {
                    seal(())
                })
            })
        } else {
            return .value(())
        }

        #elseif os(macOS)
        mainWindowController.mainViewController.activityIndicatorView.isHidden = true
        mainWindowController.mainViewController.activityIndicator.stopAnimation(nil)
        mainWindowController.mainViewController.cancellable = nil

        return .value(())
        #endif
    }
    
    func refresh(instance: Instance) -> Promise<Void> {
        showActivityIndicator(messageKey: "Fetching instance configuration")
        
        return instancesRepository.refresher.refresh(instance: instance)
            .then { api -> Promise<Void> in
                let api = self.persistentContainer.viewContext.object(with: api.objectID) as! Api //swiftlint:disable:this force_cast
                guard let authorizingDynamicApiProvider = DynamicApiProvider(api: api) else {
                    return .value(())
                }
                
                return self.refreshProfiles(for: authorizingDynamicApiProvider)
            }.ensureThen {
                self.providersViewController?.refresh()
                self.serversViewController?.refresh(animated: true)
                NotificationCenter.default.post(name: Notification.Name.InstanceRefreshed, object: self)
                return self.hideActivityIndicator()
            }.ensureThen {
                // TODO: See also ProvidersViewControllerDelegate didSelect(instance:, providersViewController: )
                #if os(macOS)
                self.dismissViewController()
                #endif
                return .value(())
            }
    }
    
    func refresh(server: Server) -> Promise<Void> {
        showActivityIndicator(messageKey: "Fetching server configuration")
        
        return serversRepository.refresher.refresh(server: server)
        // TODO
//            .then { _ -> Promise<Void> in
//             //   let api = self.persistentContainer.viewContext.object(with: api.objectID) as! Api //swiftlint:disable:this force_cast
//                guard let authorizingDynamicApiProvider = DynamicApiProvider(api: api) else {
//                    return .value(())
//                }
//
//                return self.refreshProfiles(for: authorizingDynamicApiProvider)
//            }.ensureThen {
//                self.providersViewController?.refresh()
//                self.serversViewController?.refresh(animated: true)
//                NotificationCenter.default.post(name: Notification.Name.InstanceRefreshed, object: self)
//                return self.hideActivityIndicator()
//            }.ensureThen {
//                // TODO: See also ProvidersViewControllerDelegate didSelect(instance:, providersViewController: )
//                #if os(macOS)
//                self.dismissViewController()
//                #endif
//                return .value(())
//            }
    }
    
    func fetchProfile(for profile: Profile, retry: Bool = false) -> Promise<[String]> {
        guard let api = profile.api else {
            precondition(false, "This should never happen")
            return Promise(error: AppCoordinatorError.apiMissing)
        }

        guard let profileId = profile.profileId else {
            precondition(false, "This should never happen")
            return Promise(error: AppCoordinatorError.profileIdMissing)
        }

        guard let dynamicApiProvider = DynamicApiProvider(api: api) else {
            return Promise(error: AppCoordinatorError.apiProviderCreateFailed)
        }
        
        setActivityIndicatorMessage(key: "Loading certificate")
        
        return loadCertificate(for: api)
            .then { _ -> Promise<Response> in
                self.setActivityIndicatorMessage(key: "Requesting profile config")
                return dynamicApiProvider.request(apiService: .profileConfig(profileId: profileId))
            }.map { response -> [String] in
                guard var ovpnFileContent = String(data: response.data, encoding: .utf8) else {
                    throw AppCoordinatorError.ovpnConfigTemplate
                }
                
                ovpnFileContent = self.forceTcp(on: ovpnFileContent)
                try self.validateRemote(on: ovpnFileContent)

                guard let certificateModel = api.certificateModel else {
                    throw AppCoordinatorError.certificateModelMissing
                }
                ovpnFileContent = try self.merge(key: certificateModel.privateKeyString, certificate: certificateModel.certificateString, into: ovpnFileContent)
                let lines = ovpnFileContent.components(separatedBy: .newlines).map {
                    $0.trimmingCharacters(in: .whitespacesAndNewlines)
                }.filter {
                    !$0.isEmpty
                }

                return lines
            }.recover { (error) throws -> Promise<[String]> in
                if retry {
                    self.showError(error)
                    throw error
                }
                
                if let nsError = error as NSError?, nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorNetworkConnectionLost {
                    return self.retryFetchProfile(with: dynamicApiProvider, for: profile)
                }
                
                switch error {
                    
                case ApiServiceError.tokenRefreshFailed, ApiServiceError.noAuthState :
                    return self.retryFetchProfile(with: dynamicApiProvider, for: profile)

                default:
                    return self.hideActivityIndicator().then { _ -> Guarantee<[String]> in
                        self.showError(error)
                        throw error
                    }
                }
            }
    }

    private func retryFetchProfile(with dynamicApiProvider: DynamicApiProvider, for profile: Profile) -> Promise<[String]> {
        self.authorizingDynamicApiProvider = dynamicApiProvider
        #if os(iOS)
        let authorizeRequest = dynamicApiProvider.authorize(presentingViewController: self.navigationController)
        self.showActivityIndicator(messageKey: "Authorizing with provider")
        #elseif os(macOS)
        let authorizeRequest = dynamicApiProvider.authorize()
        self.showActivityIndicator(messageKey: "Authorizing with provider", cancellable: authorizeRequest)
        #endif

        return authorizeRequest.then { _ -> Promise<[String]> in
            return self.hideActivityIndicator().then { _ -> Promise<[String]> in
                #if os(macOS)
                NSApp.activate(ignoringOtherApps: true)
                #endif
                return self.fetchProfile(for: profile, retry: true)
            }
        }
    }
    
    private func refreshProfiles(for dynamicApiProvider: DynamicApiProvider) -> Promise<Void> {
        showActivityIndicator(messageKey: "Refreshing profiles")
        
        return ProfilesRepository.shared.refresher.refresh(for: dynamicApiProvider)
            .recover { error throws -> Promise<Void> in
                switch error {
                    
                case ApiServiceError.tokenRefreshFailed, ApiServiceError.noAuthState:
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
                            return self.hideActivityIndicator().then { _ -> Promise<Void> in
                                #if os(macOS)
                                NSApp.activate(ignoringOtherApps: true)
                                #endif
                                return self.refreshProfiles(for: dynamicApiProvider)
                            }
                        }
                        .recover { error throws in
                            self.hideActivityIndicator().then { _ -> Guarantee<Void> in
                                self.showError(error)
                                return .value(())
                            }
                            throw error
                        }
                default:
                    return self.hideActivityIndicator().then { _ -> Guarantee<Void> in
                        self.showError(error)
                        throw error
                    }
                }
            }
    }
}

extension Notification.Name {
    static let InstanceRefreshed = Notification.Name("InstanceRefreshed")
}
