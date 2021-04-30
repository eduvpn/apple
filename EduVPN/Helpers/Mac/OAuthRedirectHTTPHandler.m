//
//  OAuthRedirectHTTPHandler.m
//  EduVPN
//
//  Derived from OIDRedirectHTTPHandler.m in the AppAuth iOS SDK
//
//  Copyright 2016 Google Inc.
//  Copyright 2021 The Commons Conservancy
//  All Rights Reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

#import "OAuthRedirectHTTPHandler.h"
#import "OIDLoopbackHTTPServer.h"

static NSString *const kHTMLPageTemplate = @""
    "<!DOCTYPE html>"
    "<html lang=\"en\" dir=\"ltr\" xmlns=\"http://www.w3.org/1999/xhtml\">"
    "<head>"
    "    <meta charset=\"utf-8\" />"
    "    <title>%@</title>"
    "    <style>"
    "body {"
    "    font-family: -apple-system, BlinkMacSystemFont, \"Avenir Next\", Avenir,"
    "                 \"Nimbus Sans L\", Roboto, Noto, \"Segoe UI\", Arial,"
    "                 Helvetica, \"Helvetica Neue\", sans-serif;"
    "    margin: 0;"
    "    height: 100vh;"
    "    display: flex;"
    "    align-items: center;"
    "    justify-content: center;"
    "    background: #ccc;"
    "    color: #888;"
    "}"
    "main {"
    "    padding: 1em 2em;"
    "    text-align: center;"
    "    border: 1pt solid #666;"
    "    box-shadow: rgba(0, 0, 0, 0.2) 0px 1px 4px;"
    "    border-color: #aaa;"
    "    background: #ddd;"
    "}"
    "    </style>"
    "</head>"
    "<body class=\"finished\">"
    "    <main>"
    "        <h2>%@</h2>"
    "        <p>%@</p>"
    "    </main>"
    "</body>"
    "</html>";

static NSString *const kStringsAuthorizationComplete[] =
    {
        @"Authorization Successful",
        @"The client authorized succesfully",
        @"You can now close this tab."
    };

static NSString *const kStringsErrorMissingCurrentAuthorizationFlow[] =
    {
        @"Authorization Error",
        @"Authorization Error",
        @"AppAuth Error: No <code>currentAuthorizationFlow</code> is set on the "
         "<code>OIDRedirectHTTPHandler</code>. Cannot process redirect."
    };

static NSString *const kStringsErrorRedirectNotValid[] =
    {
        @"Authorization Error",
        @"Authorization Error",
        @"AppAuth Error: Not a valid redirect."
    };

@implementation OAuthRedirectHTTPHandler

#pragma clang diagnostic ignored "-Wundeclared-selector"

- (void)HTTPConnection:(HTTPConnection *)conn didReceiveRequest:(HTTPServerRequest *)mess {
  // Sends URL to AppAuth.
  CFURLRef url = CFHTTPMessageCopyRequestURL(mess.request);
  BOOL handled = [[self currentAuthorizationFlow] resumeExternalUserAgentFlowWithURL:(__bridge NSURL *)url];

  // Stops listening to further requests after the first valid authorization response.
  if (handled) {
      [self setCurrentAuthorizationFlow: nil];
      if ([self respondsToSelector:@selector(stopHTTPListener)]) {
          [self performSelector:@selector(stopHTTPListener)];
      }
  }

  NSString *bodyText = @"";
  NSInteger httpResponseCode = 0;

  if (handled) {
    bodyText = [NSString stringWithFormat:kHTMLPageTemplate,
                kStringsAuthorizationComplete[0],
                kStringsAuthorizationComplete[1],
                kStringsAuthorizationComplete[2]];
    httpResponseCode = 200;
  } else if ([self currentAuthorizationFlow]) {
    bodyText = [NSString stringWithFormat:kHTMLPageTemplate,
                kStringsErrorMissingCurrentAuthorizationFlow[0],
                kStringsErrorMissingCurrentAuthorizationFlow[1],
                kStringsErrorMissingCurrentAuthorizationFlow[2]];
    httpResponseCode = 404;
  } else {
    bodyText = [NSString stringWithFormat:kHTMLPageTemplate,
                kStringsErrorRedirectNotValid[0],
                kStringsErrorRedirectNotValid[1],
                kStringsErrorRedirectNotValid[2]];
    httpResponseCode = 400;
  }

  NSAssert([bodyText length] > 0, @"bodyText is empty");
  NSAssert(httpResponseCode > 0, @"httpResponseCode is %ld, should be greater than 0", (long) httpResponseCode);

  NSData *data = [bodyText dataUsingEncoding:NSUTF8StringEncoding];

  CFHTTPMessageRef response = CFHTTPMessageCreateResponse(kCFAllocatorDefault,
                                                          httpResponseCode,
                                                          NULL,
                                                          kCFHTTPVersion1_1);
  CFHTTPMessageSetHeaderFieldValue(response,
                                   (__bridge CFStringRef)@"Content-Length",
                                   (__bridge CFStringRef)[NSString stringWithFormat:@"%lu",
                                       (unsigned long)data.length]);
  CFHTTPMessageSetBody(response, (__bridge CFDataRef)data);

  [mess setResponse:response];
  CFRelease(response);
}

@end
