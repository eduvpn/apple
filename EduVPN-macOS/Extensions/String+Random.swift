//
//  String+Random.swift
//  eduVPN
//

import Foundation

extension String {
    
    subscript(idx: Int) -> Character {
        return self[index(startIndex, offsetBy: idx)]
    }
    
    static func random(length: Int = 32,
                       alphabet: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567") -> String {
        
        let upperBound = alphabet.count
        return String((0..<length).map { _ -> Character in
            return alphabet[Int.random(in: 0..<upperBound)]
        })
    }
}
