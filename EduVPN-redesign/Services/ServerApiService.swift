//
//  ServerApiService.swift
//  EduVPN
//
//  Created by Johan Kool on 24/06/2020.
//

import Foundation
import PromiseKit

protocol ServerApiServiceType {
    func profileConfig(for profile: Profile) -> Promise<[String]>
}


class ServerApiService: ServerApiServiceType {
    
    func profileConfig(for profile: Profile) -> Promise<[String]> {
        let promise = Promise()
        return prom
    }
    
}
