//
//  JSONSerializable.swift
//  EduVPN
//
//  Created by Jeroen Leenarts on 06-08-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

protocol JSONSerializable {
    var jsonDictionary: [String : Any] { get }
}
