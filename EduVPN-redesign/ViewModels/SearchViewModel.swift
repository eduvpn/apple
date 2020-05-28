//
//  SearchViewModel.swift
//  EduVPN
//
//  Created by Johan Kool on 28/05/2020.
//  Copyright © 2020 SURFNet. All rights reserved.
//

import Foundation
import PromiseKit

class SearchViewModel {
    
    let environment: Environment
    
    init(environment: Environment) {
        self.environment = environment
    }
    
    func search(query: String) -> Promise<Void> {
        return .value(())
    }
    
}
