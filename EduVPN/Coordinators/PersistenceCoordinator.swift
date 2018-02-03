//
//  PersistenceCoordinator.swift
//  EduVPN
//
//  Created by Jeroen Leenarts on 02-02-18.
//  Copyright © 2018 SURFNet. All rights reserved.
//

import Foundation

import Disk

protocol PersistenceCoordinatorDelegate: class {
    func showError(_ error: Error)
}

class PersistenceCoordinator {
    public static let InternetInstancesDidUpdate = NSNotification.Name("EduVPNInternetInstancesDidUpdate")
    public static let InstituteInstancesDidUpdate = NSNotification.Name("EduVPNInstituteInstancesDidUpdate")
    public static let OtherInstancesDidUpdate = NSNotification.Name("EduVPNOtherInstancesDidUpdate")

    public static let InstanceInfoProfilesMappingDidUpdate = NSNotification.Name("EduVPNInstanceInfoProfilesMappingDidUpdate")

    weak var delegate: PersistenceCoordinatorDelegate?

    var instanceInfoProfilesMapping: [InstanceInfoModel: ProfilesModel] {
        get {
            do {
                return try Disk.retrieve("instanceInfoProfilesMapping.json", from: .documents, as: [InstanceInfoModel: ProfilesModel].self)
            } catch {
                print(error)
                return [InstanceInfoModel: ProfilesModel]()
            }
        }
        set {
            do {
                try Disk.save(newValue, to: .documents, as: "instanceInfoProfilesMapping.json")
                NotificationCenter.default.post(name: PersistenceCoordinator.InstanceInfoProfilesMappingDidUpdate, object: self)
            } catch {
                delegate?.showError(error)
                print(error)
            }
        }
    }

    var internetInstancesModel: InstancesModel? {
        get {
            do {
                return try Disk.retrieve("internet-instances.json", from: .documents, as: InstancesModel.self)
            } catch {
                print(error)
                return nil
            }
        }
        set {
            do {
                try Disk.save(newValue, to: .documents, as: "internet-instances.json")
                NotificationCenter.default.post(name: PersistenceCoordinator.InternetInstancesDidUpdate, object: self)
            } catch {
                delegate?.showError(error)
                print(error)
            }
        }
    }

    var instituteInstancesModel: InstancesModel? {
        get {
            do {
                return try Disk.retrieve("institute-instances.json", from: .documents, as: InstancesModel.self)
            } catch {
                print(error)
                return InstancesModel(providerType: .other, authorizationType: .local, seq: 0, signedAt: nil, instances: [], authorizationEndpoint: nil, tokenEndpoint: nil)
            }
        }
        set {
            do {
                try Disk.save(newValue, to: .documents, as: "institute-instances.json")
                NotificationCenter.default.post(name: PersistenceCoordinator.InstituteInstancesDidUpdate, object: self)
            } catch {
                delegate?.showError(error)
                print(error)
            }
        }
    }

    var otherInstancesModel: InstancesModel? {
        get {
            do {
                return try Disk.retrieve("other-instances.json", from: .documents, as: InstancesModel.self)
            } catch {
                print(error)
                return nil
            }
        }
        set {
            do {
                try Disk.save(newValue, to: .documents, as: "other-instances.json")
                NotificationCenter.default.post(name: PersistenceCoordinator.OtherInstancesDidUpdate, object: self)
            } catch {
                print(error)
                delegate?.showError(error)
            }
        }
    }
}
