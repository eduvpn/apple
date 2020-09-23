//
//  AppDelegate.m
//  LoginItemHelper
//

#import "AppDelegate.h"

@interface AppDelegate ()

@end

@implementation AppDelegate

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification {
    NSBundle *helperBundle = [NSBundle mainBundle];
    NSString *helperBundleId = [helperBundle bundleIdentifier];

    NSString *suffix = @".LoginItemHelper";
    if ([helperBundleId hasSuffix:suffix]) {
        NSString *appBundleId = [helperBundleId
                                 substringToIndex: (helperBundleId.length - suffix.length)];
        NSAppleEventDescriptor *paramDescriptor = [NSAppleEventDescriptor
                                                   descriptorWithString:helperBundleId];
        [[NSWorkspace sharedWorkspace]
         launchAppWithBundleIdentifier:appBundleId
         options:NSWorkspaceLaunchAndHide
         additionalEventParamDescriptor:paramDescriptor
         launchIdentifier:NULL];
    }

    [NSApp terminate:nil];
}

@end
