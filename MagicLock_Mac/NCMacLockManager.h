//
//  NCMacLockManager.h
//  MagicLock_MacOS
//
//  Created by 程启航 on 2017/5/11.
//  Copyright © 2017年 NcnkCheng. All rights reserved.
//

#import <Foundation/Foundation.h>


typedef NS_OPTIONS(NSInteger, NCMacLockType) {
    NCMacLockTypeSleep                      = 0,
    NCMacLockTypeScreensaver                = 1,
};


@interface NCMacLockConfig : NSObject

+ (instancetype)globalConfig;

@property (nonatomic, copy) NSString *password;
@property (nonatomic, assign) NCMacLockType lockType;

@end


@interface NCMacLockManager : NSObject

+ (instancetype)sharedInstance;

- (void)lock;
- (void)unlock;

@end
