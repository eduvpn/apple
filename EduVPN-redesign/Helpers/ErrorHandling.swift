//
//  AppError.swift
//  EduVPN
//

import Foundation
import Alamofire

protocol AppError: Error {
    var summary: String { get }
    var detail: String { get }
}

extension AppError {
    var detail: String { "" }
}

extension Error {
    var innerError: Error? {
        if let afError = self as? Alamofire.AFError {
            switch afError {
            case .sessionInvalidated(let error):
                return error
            case .sessionTaskFailed(let error):
                return error
            default:
                break
            }
        } else if let userInfoUnderlyingError =
            (self as NSError).userInfo[NSUnderlyingErrorKey] as? NSError {
            return userInfoUnderlyingError
        }
        return nil
    }

    var innermostLocalizedDescription: String {
        var description = self.localizedDescription
        var current: Error = self
        while true {
            if let next = current.innerError {
                if let nextValue = (next as NSError).userInfo[NSLocalizedDescriptionKey] as? String {
                    description = nextValue
                }
                current = next
            } else {
                break
            }
        }
        return description
    }

    var innermostFailingURLString: String? {
        var urlString: String? = nil
        var current: Error = self
        while true {
            if let next = current.innerError {
                if let nextValue = (next as NSError).userInfo[NSURLErrorFailingURLStringErrorKey] as? String {
                    urlString = nextValue
                }
                current = next
            } else {
                break
            }
        }
        return urlString
    }

    var alertSummary: String {
        if let appError = self as? AppError {
            return appError.summary
        }
        return innermostLocalizedDescription
    }

    var alertDetail: String? {
        if let appError = self as? AppError {
            return appError.detail
        }
        if let urlString = innermostFailingURLString {
            return String(format: NSLocalizedString("Failing URL: %@", comment: ""), urlString)
        }
        let userInfo = (self as NSError).userInfo
        if !userInfo.isEmpty {
            return "\(userInfo)"
        }
        return nil
    }
}
