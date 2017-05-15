//
//  NCPeripheralManager.h
//  MagicLock
//
//  Created by 程启航 on 2017/4/6.
//
//

#import <Foundation/Foundation.h>

@interface NCPeripheralManager : NSObject

+ (instancetype)sharedInstance;
- (void)startAdvertising;

@property (nonatomic, strong, readonly) NSString *phoneName;
@property (nonatomic, strong, readonly) NSString *realDistance;
@property (nonatomic, assign) NSInteger lockDistance;

@end
