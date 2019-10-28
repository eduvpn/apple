//
//  InstanceService.swift
//  eduVPN
//
//  Created by Jeroen Leenarts on 01-08-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

import Foundation
import Moya
import Result

struct DynamicInstanceService: TargetType, AcceptJson {
    
    let baseURL: URL

    var path: String { return "/info.json" }
    var method: Moya.Method { return .get }
    var task: Task { return .requestPlain }
    var sampleData: Data { return "".data(using: String.Encoding.utf8)! }
}
