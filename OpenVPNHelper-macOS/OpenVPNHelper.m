//
//  OpenVPNHelper.m
//  eduVPN
//
//  Created by Johan Kool on 03/07/2017.
//  Copyright © 2017-2019 Commons Conservancy.
//

#import "OpenVPNHelper.h"
#include <syslog.h>

NSString *const OpenVPNHelperErrorDomain = @"OpenVPNHelperErrorDomain";
NSString *const OpenVPNHelperErrorDangerousCommandsKey = @"OpenVPNHelperErrorDangerousCommandsKey";

@interface OpenVPNHelper () <NSXPCListenerDelegate, OpenVPNHelperProtocol>

@property (atomic, strong, readwrite) NSXPCListener *listener;
@property (atomic, strong) NSTask *openVPNTask;
@property (atomic, copy) NSString *logFilePath;
@property (atomic, strong) id <ClientProtocol> remoteObject;

@end

@implementation OpenVPNHelper

- (id)init {
    self = [super init];
    if (self != nil) {
        // Set up our XPC listener to handle requests on our Mach service.
        self->_listener = [[NSXPCListener alloc] initWithMachServiceName:kHelperToolMachServiceName];
        self->_listener.delegate = self;
    }
    return self;
}

- (void)run {
    // Tell the XPC listener to start processing requests.
    [self.listener resume];
    
    // Run the run loop forever.
    [[NSRunLoop currentRunLoop] run];
}

// Called by our XPC listener when a new connection comes in.  We configure the connection
// with our protocol and ourselves as the main object.
- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection {
    assert(listener == self.listener);
    assert(newConnection != nil);
    
    newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(OpenVPNHelperProtocol)];
    newConnection.exportedObject = self;
    newConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(ClientProtocol)];
    newConnection.invalidationHandler = ^ {
        [self closeWithReply:nil];
    };
    self.remoteObject = newConnection.remoteObjectProxy;
    [newConnection resume];
    
    return YES;
}

- (void)getVersionWithReply:(void(^)(NSString * version))reply {
    NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"?";
    NSString *buildVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"] ?: @"?";
    reply([NSString stringWithFormat:@"%@-%@", version, buildVersion]);
}

- (BOOL)verify:(NSString *)identifier atURL:(NSURL *)fileURL {
    SecStaticCodeRef staticCodeRef = 0;
    OSStatus status = SecStaticCodeCreateWithPath((__bridge CFURLRef _Nonnull)(fileURL), kSecCSDefaultFlags, &staticCodeRef);
    if (status != errSecSuccess) {
        syslog(LOG_ERR, "Static code error %d", status);
        return NO;
    }
    
    NSString *requirement = [NSString stringWithFormat:@"anchor apple generic and identifier %@ and certificate leaf[subject.OU] = %@", identifier, TEAM];
    SecRequirementRef requirementRef = 0;
    status = SecRequirementCreateWithString((__bridge CFStringRef _Nonnull)requirement, kSecCSDefaultFlags, &requirementRef);
    if (status != errSecSuccess) {
        syslog(LOG_ERR, "Requirement error %d", status);
        return NO;
    }
    
    status = SecStaticCodeCheckValidity(staticCodeRef, kSecCSDefaultFlags, requirementRef);
    if (status != errSecSuccess) {
        syslog(LOG_ERR, "Validity error %d", status);
        return NO;
    }
    
    return YES;
}

- (void)startOpenVPNAtURL:(NSURL *_Nonnull)launchURL withConfig:(NSURL *_Nonnull)config upScript:(NSURL *_Nullable)upScript downScript:(NSURL *_Nullable)downScript leasewatchPlist:(NSURL *_Nullable)leasewatchPlist leasewatchScript:(NSURL *_Nullable)leasewatchScript scriptOptions:(NSArray <NSString *>*_Nullable)scriptOptions reply:(void(^_Nonnull)(NSError *))reply {

    syslog(LOG_NOTICE, "Validating configuration file");

    NSData *configFileData = [NSData dataWithContentsOfURL:config];
    if (configFileData == nil) {
        reply([NSError errorWithDomain:OpenVPNHelperErrorDomain
                                  code:OpenVPNHelperErrorUnreadableConfigurationFile
                              userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"OpenVPN configuration file could not be read", @""),
                                         NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"Ensure the configuration file exists and is readable or try again later.", @"")}]);
        return;
    }

    NSString *configFileString = [[NSString alloc] initWithData:configFileData encoding:NSUTF8StringEncoding];
    if (configFileString == nil) {
        reply([NSError errorWithDomain:OpenVPNHelperErrorDomain
                                  code:OpenVPNHelperErrorUnexpectedEncodingConfigurationFile
                              userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"OpenVPN configuration file had unexpected encoding", @""),
                                         NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"Ensure the configuration file is using UTF8 encoding or try again later.", @"")}]);
        return;
    }

    NSArray *configLines = [configFileString componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSArray *dangerousCommands = @[@"up", @"tls-verify", @"ipchange", @"client-connect", @"route-up", @"route-pre-down", @"client-disconnect", @"down", @"learn-address", @"auth-user-pass-verify", @"script-security"];
    NSMutableSet *dangerousCommandsFound = [NSMutableSet set];

    for (NSString *line in configLines) {
        NSString *trimmedLine = [[line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] lowercaseString];
        NSArray *lineComponents = [trimmedLine componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        NSString *firstComponent = [lineComponents firstObject];
        if (firstComponent != nil && ([firstComponent isEqualToString:@"#"] || [firstComponent isEqualToString:@";"])) {
            // Ignore comments
            continue;
        } else {
            NSArray *matches = [lineComponents filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
                return [dangerousCommands containsObject:evaluatedObject];
            }]];
            if (matches.count > 0) {
                syslog(LOG_WARNING, "Found potentially dangerous command(s) %s", [[matches componentsJoinedByString:@" "] UTF8String]);
                [dangerousCommandsFound addObjectsFromArray:matches];
            }
        }
    }

    if (dangerousCommandsFound.count > 0){
        BOOL singleCommand = dangerousCommandsFound.count == 1;
        reply([NSError errorWithDomain:OpenVPNHelperErrorDomain
                                  code:OpenVPNHelperErrorDangerousCommandsInConfigurationFile
                              userInfo: singleCommand ? @{OpenVPNHelperErrorDangerousCommandsKey: [dangerousCommandsFound allObjects],
                                                          NSLocalizedDescriptionKey: NSLocalizedString(@"OpenVPN configuration file contains a dangerous command", @""),
                                                          NSLocalizedRecoverySuggestionErrorKey: [NSString stringWithFormat:NSLocalizedString(@"Remove the dangerous command (%@) if possible and try again.", @""), [[dangerousCommandsFound allObjects] componentsJoinedByString:@", "]]
                                                          } : @{OpenVPNHelperErrorDangerousCommandsKey: [dangerousCommandsFound allObjects],
                                                                NSLocalizedDescriptionKey: NSLocalizedString(@"OpenVPN configuration file contains multiple dangerous commands", @""),
                                                                NSLocalizedRecoverySuggestionErrorKey: [NSString stringWithFormat:NSLocalizedString(@"Remove the dangerous commands (%@) if possible and try again.", @""), [[dangerousCommandsFound allObjects] componentsJoinedByString:@", "]]
                                                                }]);
        return;
    }

    syslog(LOG_NOTICE, "Verifying signatures");

    // Verify that binary at URL is signed by us
    if (![self verify:@"openvpn" atURL:launchURL]) {
        reply([NSError errorWithDomain:OpenVPNHelperErrorDomain
                                  code:OpenVPNHelperErrorBinarySignatureNotSignedByUs
                              userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"OpenVPN binary has unexpected signature", @""),
                                         NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"Try reinstalling eduVPN.", @"")}]);
        return;
    }
    
    // Verify that up script at URL is signed by us
    if (upScript && ![self verify:@"client.up.eduvpn" atURL:upScript]) {
        reply([NSError errorWithDomain:OpenVPNHelperErrorDomain
                                  code:OpenVPNHelperErrorUpScriptSignatureNotSignedByUs
                              userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"OpenVPN up script has unexpected signature", @""),
                                         NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"Try reinstalling eduVPN.", @"")}]);
        return;
    }
    
    // Verify that down script at URL is signed by us
    if (downScript && ![self verify:@"client.down.eduvpn" atURL:downScript]) {
        reply([NSError errorWithDomain:OpenVPNHelperErrorDomain
                                  code:OpenVPNHelperErrorDownScriptSignatureNotSignedByUs
                              userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"OpenVPN down script has unexpected signature", @""),
                                         NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"Try reinstalling eduVPN.", @"")}]);
        return;
    }
    
    // Monitoring is enabled
    if ([scriptOptions containsObject:@"-m"]) {
        // Verify that lease watch script at URL is signed by us
        if (leasewatchScript && ![self verify:@"leasewatch" atURL:leasewatchScript]) {
            reply([NSError errorWithDomain:OpenVPNHelperErrorDomain
                                      code:OpenVPNHelperErrorLeasewatchScriptSignatureNotSignedByUs
                                  userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"OpenVPN leasewatch script has unexpected signature", @""),
                                             NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"Try reinstalling eduVPN.", @"")}]);
            return;
        }

        // Write plist to leasewatch
        NSDictionary *leasewatchPlistContents = @{@"Label": @"org.eduvpn.app.leasewatch",
                                                  @"ProgramArguments": @[leasewatchScript.path],
                                                  @"WatchPaths": @[@"/Library/Preferences/SystemConfiguration"]
                                                  };
        NSError *error;
        NSString *leasewatchPlistDirectory = leasewatchPlist.path.stringByDeletingLastPathComponent;
        if (![[NSFileManager defaultManager] createDirectoryAtPath:leasewatchPlistDirectory withIntermediateDirectories:YES attributes:nil error:&error]) {
            syslog(LOG_WARNING, "Error creating directory for leasewatch plist at %s: %s", leasewatchPlistDirectory.UTF8String, error.description.UTF8String);
        }
        NSString *leasewatchPlistLogsDirectory = [leasewatchPlistDirectory stringByAppendingPathComponent:@"Logs"];;
        if (![[NSFileManager defaultManager] createDirectoryAtPath:leasewatchPlistLogsDirectory withIntermediateDirectories:YES attributes:nil error:&error]) {
            syslog(LOG_WARNING, "Error creating directory for leasewatch logs at %s: %s", leasewatchPlistLogsDirectory.UTF8String, error.description.UTF8String);
        }
        if (![leasewatchPlistContents writeToURL:leasewatchPlist atomically:YES]) {
            syslog(LOG_WARNING, "Error writing watch plist contents to %s", leasewatchPlist.path.UTF8String);
        }
        
        // Make lease watch file readable
        if (![[NSFileManager defaultManager] setAttributes:@{NSFilePosixPermissions: [NSNumber numberWithShort:0744]} ofItemAtPath:leasewatchPlist.path error:&error]) {
            syslog(LOG_WARNING, "Error making lease watch plist %s executable (chmod 744): %s", leasewatchPlist.path.UTF8String, error.description.UTF8String);
        }
    }
    
    syslog(LOG_NOTICE, "Launching task");
    
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = launchURL.path;
    NSString *logFilePath = [config.path stringByAppendingString:@".log"];
    NSString *socketPath = @"/private/tmp/eduvpn.socket";
    
    NSMutableArray *arguments = [NSMutableArray arrayWithArray:@[@"--config", [self pathWithSpacesEscaped:config.path],
                                                                 @"--log", [self pathWithSpacesEscaped:logFilePath],
                                                                 @"--management", [self pathWithSpacesEscaped:socketPath], @"unix",
                                                                 @"--management-external-key",
                                                                 @"--management-external-cert", @"macosx-keychain",
                                                                 @"--management-query-passwords",
                                                                 @"--management-forget-disconnect"]];
    
    if (upScript.path) {
        [arguments addObjectsFromArray:@[@"--up", [self scriptPath:upScript.path withOptions:scriptOptions]]];
    }
    if (downScript.path) {
        [arguments addObjectsFromArray:@[@"--down", [self scriptPath:downScript.path withOptions:scriptOptions]]];
    }
    if (upScript.path || downScript.path) {
        // 2 -- allow calling of built-ins and scripts
        [arguments addObjectsFromArray:@[@"--script-security", @"2"]];
    }
    task.arguments = arguments;
    [task setTerminationHandler:^(NSTask *task){
        [[NSFileManager defaultManager] removeItemAtPath:socketPath error:NULL];
        [self.remoteObject taskTerminatedWithReply:^{
            syslog(LOG_NOTICE, "Terminated task");
        }];
    }];
    [task launch];
    
    // Create and make log file readable
    NSError *error;
    [[NSFileManager defaultManager] createFileAtPath:logFilePath contents:nil attributes:nil];
    if (![[NSFileManager defaultManager] setAttributes:@{NSFilePosixPermissions: [NSNumber numberWithShort:0644]} ofItemAtPath:logFilePath error:&error]) {
        syslog(LOG_WARNING, "Error making log file %s readable (chmod 644): %s", logFilePath.UTF8String, error.description.UTF8String);
    }
    
    self.openVPNTask = task;
    self.logFilePath = logFilePath;

    reply(task.isRunning ? nil : [NSError errorWithDomain:OpenVPNHelperErrorDomain
                                                     code:OpenVPNHelperErrorNotRunning
                                                 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"OpenVPN is not running", @""),
                                                            NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"Try again.", @"")}]);
}

- (void)closeWithReply:(void(^)(void))reply {
    [self.openVPNTask interrupt];
    self.openVPNTask = nil;
    if (reply != nil) {
        reply();
    }
}

- (NSString *)pathWithSpacesEscaped:(NSString *)path {
    return [path stringByReplacingOccurrencesOfString:@" " withString:@"\\ "];
}

- (NSString *)scriptPath:(NSString *)path withOptions:(NSArray <NSString *>*)scriptOptions {
    if (scriptOptions && [scriptOptions count] > 0) {
        NSString *escapedPath = [self pathWithSpacesEscaped:path];
        return [NSString stringWithFormat:@"%@ %@", escapedPath, [scriptOptions componentsJoinedByString:@" "]];
    } else {
        NSString *escapedPath = [self pathWithSpacesEscaped:path];
        return escapedPath;
    }
}

@end
