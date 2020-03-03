//
//  AppDelegate.m
//  LoginItemHelper
//

#import "AppDelegate.h"

@interface AppDelegate ()

@end

@implementation AppDelegate

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification {
    NSString *appPath = [[[[[[NSBundle mainBundle] bundlePath]
                            stringByDeletingLastPathComponent]
                                stringByDeletingLastPathComponent]
                                    stringByDeletingLastPathComponent]
                                        stringByDeletingLastPathComponent];
    
    [[NSWorkspace sharedWorkspace] launchApplication:appPath];
    
    [NSApp terminate:nil];
}

@end
