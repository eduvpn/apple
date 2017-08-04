//
//  ApplicationSupportFileManager.swift
//  EduVPN
//
//  Created by Jeroen Leenarts on 06-08-17.
//  Copyright © 2017 SURFNet. All rights reserved.
//

import Foundation

class ApplicationSupportFileManager {

    init(filename: String) {
        self.filename = filename
    }

    let filename: String

    func persistToDisk<T>(data: T) {
        if let appSupportDir = appSupportDir {
            let writePath = URL(fileURLWithPath: appSupportDir).appendingPathComponent(filename).path
            NSKeyedArchiver.archiveRootObject(data, toFile: writePath)
        }
    }

    func loadFromDisk<T>() -> T? {
        if let appSupportDir = appSupportDir {
            let readPath = URL(fileURLWithPath: appSupportDir).appendingPathComponent(filename).path
            return NSKeyedUnarchiver.unarchiveObject(withFile: readPath) as? T

        }

        return nil
    }

    var appSupportDir: String? {
        if let appSupportDir = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).last {
            var isDir: ObjCBool = false
            if !FileManager.default.fileExists(atPath: appSupportDir, isDirectory: &isDir) {
                try! FileManager.default.createDirectory(atPath: appSupportDir, withIntermediateDirectories: true, attributes: nil) // swiftlint:disable:this force_try
            }

            return appSupportDir
        }

        return nil
    }
}
