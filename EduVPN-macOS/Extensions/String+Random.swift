//
//  String+Random.swift
//  eduVPN
//
//  Created by Johan Kool on 18/04/2018.
//  Copyright © 2017-2019 Commons Conservancy.
//

import Foundation

extension String {
    subscript(i: Int) -> Character {
        return self[index(startIndex, offsetBy: i)]
    }
    
    static func random(length: Int = 32,
                       alphabet: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567") -> String {
        
        let upperBound = UInt32(alphabet.count)
        return String((0..<length).map { _ -> Character in
            return alphabet[Int(arc4random_uniform(upperBound))]
        })
    }
}
