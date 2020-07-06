//
//  SearchService.swift
//  eduVPN 2
//
//  Created by Johan Kool on 28/05/2020.
//

import Foundation

protocol SearchServiceType {
    init(config: Config)
    func load()
}

final class SearchService: SearchServiceType {
    
    private let config: Config
    
    init(config: Config) {
        self.config = config
    }
    
//    lazy var organizationsLoader = OrganizationsLoader(config: config)
    
    func load() {
//        organizationsLoader.load().pipe { (result) in
//            print(result)
//        }
    }
}
