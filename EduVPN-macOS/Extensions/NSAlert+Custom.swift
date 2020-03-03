//
//  NSAlert+Custom.swift
//  eduVPN
//

import AppKit

private typealias ErrorDomainAndCode = (NSErrorDomain, NSInteger)

private let ignoredOpenIdAuthErrors: [ErrorDomainAndCode] = [
    ("org.openid.appauth.general", -4),
    ("org.openid.appauth.oauth_authorization", -4)
]

private func shouldIgnoreError(_ error: NSError, ignoreList: [ErrorDomainAndCode]) -> Bool {
    return ignoreList.contains(where: { $0 as String == error.domain && $1 == error.code })
}

private func customizedOrDefaultError(_ error: NSError) -> Error {
    guard error.domain == NSURLErrorDomain, error.code == NSURLErrorServerCertificateUntrusted else {
        return error
    }
    
    var userInfo = error.userInfo
    userInfo[NSLocalizedRecoverySuggestionErrorKey] = NSLocalizedString("Contact the server administrator to request replacing the invalid certificate with a valid certificate.", comment: "")
    return NSError(domain: error.domain, code: error.code, userInfo: userInfo)
}

extension NSAlert {
    
    convenience init?(customizedError error: Error) {
        if (error as NSError).domain == NSOSStatusErrorDomain, (error as NSError).code == errSecUserCanceled {
            NSLog("Ignored error: \(error)")
            return nil
        }
        
        if shouldIgnoreError(error as NSError, ignoreList: ignoredOpenIdAuthErrors) {
            NSLog("Ignored error: \(error)")
            return nil
        }
        
        self.init(error: customizedOrDefaultError(error as NSError))
    }
}
