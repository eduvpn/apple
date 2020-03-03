//
//  URL+Unused.swift
//  eduVPN
//

import Foundation

extension URL {
    /// Gives the next unused file URL by appending a counter if needed
    ///
    /// For example: if 'Image.png' exists returns 'Image 2.png', or if that one exists too 'Image 3.png'
    ///
    /// - Returns: URL
    func nextUnusedFileURL() throws -> URL {
        var candidate = self
        let fileExtension = pathExtension
        
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = candidate.deletingPathExtension()
            var lastPathComponent = candidate.lastPathComponent
            candidate = candidate.deletingLastPathComponent()
            
            let parts = lastPathComponent.split(separator: " ")
            if  let last = parts.last, let counter = Int(last), counter > 0 {
                lastPathComponent = parts.dropLast().joined(separator: " ")  + " \(counter + 1)"
            } else {
                lastPathComponent += " 2"
            }
            
            candidate = candidate
                .appendingPathComponent(lastPathComponent)
                .appendingPathExtension(fileExtension)
        }
        
        return candidate
    }
}
