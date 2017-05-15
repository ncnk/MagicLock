//
//  NCMacLockManager.m
//  MagicLock_MacOS
//
//  Created by 程启航 on 2017/5/11.
//  Copyright © 2017年 NcnkCheng. All rights reserved.
//

#import "NCMacLockManager.h"


#define NCMACLOCKCONFIG_PASSWORD_KEY   @"NCMACLOCKCONFIG_PASSWORD_KEY"
#define NCMACLOCKCONFIG_LOCKTYPE_KEY   @"NCMACLOCKCONFIG_LOCKTYPE_KEY"


@implementation NCMacLockConfig

static NCMacLockConfig *_globalConfig = nil;
+ (instancetype)globalConfig {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _globalConfig = [NCMacLockConfig new];
    });
    return _globalConfig;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.password = [[NSUserDefaults standardUserDefaults] objectForKey:NCMACLOCKCONFIG_PASSWORD_KEY];
        self.lockType = [[[NSUserDefaults standardUserDefaults] objectForKey:NCMACLOCKCONFIG_LOCKTYPE_KEY] integerValue];
    }
    return self;
}

- (void)setPassword:(NSString *)password {
    _password = password?password:@"";
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:_password forKey:NCMACLOCKCONFIG_PASSWORD_KEY];
    [userDefaults synchronize];
}

- (void)setLockType:(NCMacLockType)lockType {
    _lockType = lockType;
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:@(_lockType) forKey:NCMACLOCKCONFIG_LOCKTYPE_KEY];
    [userDefaults synchronize];
}

@end


@interface NCMacLockManager ()
@property (nonatomic, assign) BOOL askForPassword;
@property (nonatomic, assign) NSInteger askForPasswordDelay;
@end


@implementation NCMacLockManager

static NCMacLockManager *_macLockManager = nil;
+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _macLockManager = [NCMacLockManager new];
    });
    return _macLockManager;
}

- (void)lock {
    if ([self isLocked]) return;

    [self updateSystemScreensaverConfig];
    NSString *script = @"";
    if ([NCMacLockConfig globalConfig].lockType == NCMacLockTypeSleep) {
        script = [NSString stringWithFormat:@"tell application \"System Events\" \nsleep \nend tell"];
    }
    else {
        script = [NSString stringWithFormat:@"tell application \"System Events\" \nstart current screen saver \nend tell"];
    }
    NSAppleScript *appleScript = [[NSAppleScript alloc] initWithSource:script];
    [appleScript executeAndReturnError:nil];
}

- (void)unlock {
    io_registry_entry_t r = IORegistryEntryFromPath(kIOMasterPortDefault, "IOService:/IOResources/IODisplayWrangler");
    if (r) {
        IORegistryEntrySetCFProperty(r, CFSTR("IORequestIdle"), kCFBooleanFalse);
        IOObjectRelease(r);
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        BOOL askForPassword = [[[[NSUserDefaults standardUserDefaults] persistentDomainForName:@"com.apple.screensaver"] objectForKey:@"askForPassword"] boolValue];
        if ([self isLocked] && askForPassword) {
            
            NSString *script = [NSString stringWithFormat:@"tell application \"System Events\" to keystroke return"];
            NSAppleScript *appleScript = [[NSAppleScript alloc] initWithSource:script];
            [appleScript executeAndReturnError:nil];
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    NSString *script = [NSString stringWithFormat:@"tell application \"System Events\"\nkeystroke \"%@\"\nend tell\ntell application \"System Events\"\nkeystroke return\nend tell", [NCMacLockConfig globalConfig].password];
                    NSAppleScript *appleScript = [[NSAppleScript alloc] initWithSource:script];
                    [appleScript executeAndReturnError:nil];
            });
        }
    });
}

#pragma mark -

- (BOOL)isLocked {
    BOOL locked = NO;
    CFDictionaryRef CGSessionCurrentDictionary = CGSessionCopyCurrentDictionary();
    id o = [(__bridge NSDictionary *)CGSessionCurrentDictionary objectForKey:@"CGSSessionScreenIsLocked"];
    if (o) {
        locked = [o boolValue];
    }
    CFRelease(CGSessionCurrentDictionary);
    return locked;
}

- (void)updateSystemScreensaverConfig {
    NSMutableDictionary *prefs = [[[NSUserDefaults standardUserDefaults] persistentDomainForName:@"com.apple.screensaver"] mutableCopy];
    self.askForPassword = [[prefs objectForKey:@"askForPassword"] boolValue];
    self.askForPasswordDelay = [[prefs objectForKey:@"askForPasswordDelay"] integerValue];
}

//- (void)recoverScreensaverConfig {
//    [self setScreensaverAskForPassword:self.askForPassword];
//    [self setScreensaverDelay:self.askForPasswordDelay];
//}
//
//- (void)setScreensaverDelay:(NSInteger)value {
//    NSMutableDictionary *prefs = [[[NSUserDefaults standardUserDefaults] persistentDomainForName:@"com.apple.screensaver"] mutableCopy];
//    [prefs setValue:[NSString stringWithFormat:@"%li", value] forKey:@"askForPasswordDelay"];
//    [[NSUserDefaults standardUserDefaults] setPersistentDomain:prefs forName:@"com.apple.screensaver"];
//    [[NSUserDefaults standardUserDefaults] synchronize];
//}
//
//- (void)setScreensaverAskForPassword:(BOOL)value {
//    NSMutableDictionary *prefs = [[[NSUserDefaults standardUserDefaults] persistentDomainForName:@"com.apple.screensaver"] mutableCopy];
//    [prefs setValue:[NSString stringWithFormat:@"%hhi", value] forKey:@"askForPassword"];
//    [[NSUserDefaults standardUserDefaults] setPersistentDomain:prefs forName:@"com.apple.screensaver"];
//    [[NSUserDefaults standardUserDefaults] synchronize];
//    
//    NSAppleScript *kickSecurityPreferencesScript = [[NSAppleScript alloc] initWithSource:[NSString stringWithFormat:@"tell application \"System Events\"\ntell security preferences\nset require password to wake to %@\nend tell\n", value ? @"true" : @"false"]];
//    [kickSecurityPreferencesScript executeAndReturnError:nil];
//}

@end
