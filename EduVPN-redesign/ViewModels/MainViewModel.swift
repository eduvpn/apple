//
//  MainViewModel.swift
//  EduVPN
//
//  Created by Johan Kool on 28/05/2020.
//

import Foundation

class MainViewModel {
    
    let persistenceService: PersistenceService
    
    init(persistenceService: PersistenceService) {
        self.persistenceService = persistenceService
    }
}
