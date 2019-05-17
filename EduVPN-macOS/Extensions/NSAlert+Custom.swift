//
//  NSAlert+Custom.swift
//  eduVPN
//
//  Created by Johan Kool on 24/09/2018.
//  Copyright © 2017-2019 Commons Conservancy.
//

import AppKit
//import Socket

fileprivate typealias ErrorDomainAndCode = (NSErrorDomain, NSInteger)

fileprivate let ignoredOpenIdAuthErrors: [ErrorDomainAndCode] = [
    ("org.openid.appauth.general", -4),
    ("org.openid.appauth.oauth_authorization", -4)
]

fileprivate func shouldIgnoreError(_ error: NSError, ignoreList: [ErrorDomainAndCode]) -> Bool {
    return ignoreList.contains(where: { $0 as String == error.domain && $1 == error.code })
}

fileprivate func customizedOrDefaultError(_ error: NSError) -> Error {
    guard error.domain == NSURLErrorDomain, error.code == NSURLErrorServerCertificateUntrusted else {
        return error
    }
    
    var userInfo = error.userInfo
    userInfo[NSLocalizedRecoverySuggestionErrorKey] = NSLocalizedString("Contact the server administrator to request replacing the invalid certificate with a valid certificate.", comment: "")
    return NSError(domain: error.domain, code: error.code, userInfo: userInfo)
}

extension NSAlert {
    convenience init?(customizedError error: Error) {
        // TODO: <Restore upon dependencies install>
        
//        // TODO: Clean up and include in switch statement below
//        if let error = error as? ConnectionService.Error, (error.errorDescription == ConnectionService.Error.userCancelled.errorDescription || error.errorDescription == ConnectionService.Error.unexpectedState.errorDescription) {
//            NSLog("Ignored error: \(error)")
//            return nil
//        } else if (error as NSError).domain == NSOSStatusErrorDomain, (error as NSError).code == errSecUserCanceled {
//            NSLog("Ignored error: \(error)")
//            return nil
//        } else if let error = error as? Socket.Error, [1, -9974].contains(error.errorCode) {
//            NSLog("Ignored error: \(error)")
//            return nil
//        }
    
        // TODO: </Restore upon dependencies install>
        
        if shouldIgnoreError(error as NSError, ignoreList: ignoredOpenIdAuthErrors) {
            NSLog("Ignored error: \(error)")
            return nil
        }
        
        self.init(error: customizedOrDefaultError(error as NSError))
    }
}
