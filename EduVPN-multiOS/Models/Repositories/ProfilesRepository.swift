//
//  ProfilesRepository.swift
//  eduVPN
//

import CoreData
import Foundation
import PromiseKit

struct ProfilesRepository {
    
    static let shared = ProfilesRepository()
    let refresher = ProfilesRefresher()
}

// MARK: - ProfilesRefresher

class ProfilesRefresher {
    weak var persistentContainer: NSPersistentContainer!
    
    func refresh(for dynamicApiProvider: DynamicApiProvider) -> Promise<Void> {
        return dynamicApiProvider
            .request(apiService: .profileList)
            .then { response -> Promise<ProfilesModel> in response.mapResponse() }
            .then { profiles -> Promise<Void> in
                if profiles.profiles.isEmpty {
                    #if os(iOS)
                    (UIApplication.shared.delegate as? AppDelegate)?.appCoordinator.showNoProfilesAlert()
                    #elseif os(macOS)
                    (NSApp.delegate as? AppDelegate)?.appCoordinator.showNoProfilesAlert()
                    #endif
                }
                
                return Promise<Void>(resolver: { seal in
                    self.persistentContainer.performBackgroundTask { context in
                        if let api = context.object(with: dynamicApiProvider.api.objectID) as? Api {
                            Profile.upsert(with: profiles.profiles, for: api, on: context)
                        }
                        do {
                            try context.save()
                        } catch {
                            seal.reject(error)
                        }
                        
                        seal.fulfill(())
                    }
                })
            }
    }
}
