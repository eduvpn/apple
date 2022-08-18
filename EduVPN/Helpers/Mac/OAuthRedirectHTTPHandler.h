//
//  OAuthRedirectHTTPHandler.h
//  EduVPN
//

#ifndef OAuthRedirectHTTPHandler_h
#define OAuthRedirectHTTPHandler_h

#ifdef TARGET_OS_OSX

#import <Foundation/Foundation.h>
#import "macOS/OIDRedirectHTTPHandler.h"

@interface OAuthRedirectHTTPHandler: OIDRedirectHTTPHandler
@end

#endif

#endif /* OAuthRedirectHTTPHandler_h */
