//
//  OAuthRedirectHTTPHandler.h
//  EduVPN
//

#ifndef OAuthRedirectHTTPHandler_h
#define OAuthRedirectHTTPHandler_h

#ifndef TARGET_OS_IOS

#import <Foundation/Foundation.h>
#import "macOS/OIDRedirectHTTPHandler.h"
#import "macOS/LoopbackHTTPServer/OIDLoopbackHTTPServer.h"

@interface OAuthRedirectHTTPHandler: OIDRedirectHTTPHandler
@end

#endif

#endif /* OAuthRedirectHTTPHandler_h */
