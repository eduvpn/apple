//
//  NSAlert+Custom.swift
//  eduVPN
//
//  Created by Johan Kool on 24/09/2018.
//  Copyright © 2017-2019 Commons Conservancy.
//

import AppKit
//import Socket

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
        
        switch ((error as NSError).domain, (error as NSError).code) {
        case ("org.openid.appauth.general", -4),
             ("org.openid.appauth.oauth_authorization", -4):
            NSLog("Ignored error: \(error)")
            return nil
        case (NSURLErrorDomain, NSURLErrorServerCertificateUntrusted):
            var userInfo = (error as NSError).userInfo
            userInfo[NSLocalizedRecoverySuggestionErrorKey] = NSLocalizedString("Contact the server administrator to request replacing the invalid certificate with a valid certificate.", comment: "")
            let customizedError = NSError(domain: (error as NSError).domain, code: (error as NSError).code, userInfo: userInfo)
            self.init(error: customizedError)
        default:
            self.init(error: error)
        }
    }

}
