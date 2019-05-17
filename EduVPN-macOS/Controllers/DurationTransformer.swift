//
//  DurationTransformer.swift
//  eduVPN
//
//  Created by Johan Kool on 23/08/2017.
//  Copyright © 2017-2019 Commons Conservancy.
//

import Foundation

class DurationTransformer: ValueTransformer {
    
    let formatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .positional
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()
    
    override func transformedValue(_ value: Any?) -> Any? {
        guard let value = value as? DateComponents else {
            return nil
        }
        return formatter.string(from: value)
    }
    
}
