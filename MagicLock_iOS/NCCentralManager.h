//
//  NCCentralManager.h
//  MagicLock
//
//  Created by 程启航 on 2017/4/6.
//
//

#import <Foundation/Foundation.h>

@interface NCCentralManager : NSObject

+ (instancetype)sharedInstance;

- (void)start;

@end
