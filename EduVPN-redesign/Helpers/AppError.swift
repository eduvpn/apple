//
//  AppError.swift
//  EduVPN
//

import Foundation

protocol AppError: Error {
    var summary: String { get }
    var detail: String { get }
}

extension AppError {
    var detail: String { "" }
}
