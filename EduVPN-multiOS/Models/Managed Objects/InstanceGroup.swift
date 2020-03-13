//
//  InstanceGroup.swift
//  EduVPN
//
//  Created by Johan Kool on 12/03/2020.
//  Copyright © 2020 SURFNet. All rights reserved.
//

import Foundation

extension InstanceGroup {
    
    var authorizationTypeEnum: AuthorizationType {
        guard let authorizationTypeString = authorizationType else { return .local }
        return AuthorizationType(rawValue: authorizationTypeString) ?? .local
    }

}
