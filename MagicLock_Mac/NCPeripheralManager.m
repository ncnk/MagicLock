//
//  NCPeripheralManager.m
//  MagicLock
//
//  Created by 程启航 on 2017/4/6.
//
//

#import "NCPeripheralManager.h"
#import <CoreBluetooth/CoreBluetooth.h>
#import "NCMacLockManager.h"
#import "PublicMacro.h"

#define NCPERIPHERALMANAGER_MAKESURECOUNT   3
#define NCPERIPHERALMANAGER_DISTANCE_KEY    @"NCPERIPHERALMANAGER_DISTANCE_KEY"

#define NCPERIPHERALMANAGER_DEFAULT_LOCKDISTANCE    5
#define NCPERIPHERALMANAGER_MAX_LOCKDISTANCE    10
#define NCPERIPHERALMANAGER_MIN_LOCKDISTANCE    2

@interface NCPeripheralManager ()<CBPeripheralManagerDelegate>

@property (nonatomic, strong) CBPeripheralManager *manager;
@property (nonatomic, strong) CBCharacteristic *heartbeatCharacteristic;
@property (nonatomic, assign) NSInteger makeSureFlag;

@property (nonatomic, strong) NSString *phoneName;
@property (nonatomic, strong) NSString *realDistance;

@property (nonatomic, strong) NSTimer *timeoutTimer;

@end


@implementation NCPeripheralManager

static NCPeripheralManager *_peripheralManager = nil;
+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _peripheralManager = [NCPeripheralManager new];
    });
    return _peripheralManager;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.lockDistance = [[[NSUserDefaults standardUserDefaults] objectForKey:NCPERIPHERALMANAGER_DISTANCE_KEY] integerValue];
        if (self.lockDistance==0) {
            self.lockDistance = NCPERIPHERALMANAGER_DEFAULT_LOCKDISTANCE;
        }
    }
    return self;
}

- (void)startAdvertising {
    if (!self.manager) {
        self.manager = [[CBPeripheralManager alloc] initWithDelegate:self
                                                               queue:nil
                                                             options:nil];
    }
}

- (NSString *)deviceName {
    return [[NSHost currentHost] localizedName];
}

- (void)setLockDistance:(NSInteger)lockDistance {
    _lockDistance = lockDistance;
    if (_lockDistance<NCPERIPHERALMANAGER_MIN_LOCKDISTANCE) {
        _lockDistance = NCPERIPHERALMANAGER_MIN_LOCKDISTANCE;
    }
    if (_lockDistance>NCPERIPHERALMANAGER_MAX_LOCKDISTANCE) {
        _lockDistance = NCPERIPHERALMANAGER_MAX_LOCKDISTANCE;
    }
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:@(_lockDistance) forKey:NCPERIPHERALMANAGER_DISTANCE_KEY];
    [userDefaults synchronize];
}

#pragma mark - CBPeripheralManagerDelegate

- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral {
    switch (peripheral.state) {
        case CBPeripheralManagerStatePoweredOn:
        {
            CBMutableCharacteristic *heartbeatCharacteristic = [[CBMutableCharacteristic alloc] initWithType:MAGICLOCK_CHARACTERISTIC_HEARTBEAT_UUID properties:CBCharacteristicPropertyNotify value:nil permissions:CBAttributePermissionsReadable];
            CBMutableCharacteristic *writeCharacteristic = [[CBMutableCharacteristic alloc] initWithType:MAGICLOCK_CHARACTERISTIC_WRITE_UUID properties:CBCharacteristicPropertyWrite value:nil permissions:CBAttributePermissionsWriteable];
            CBMutableCharacteristic *readCharacteristic = [[CBMutableCharacteristic alloc] initWithType:MAGICLOCK_CHARACTERISTIC_READ_UUID properties:CBCharacteristicPropertyRead value:nil permissions:CBAttributePermissionsReadable];
            
            CBMutableService *service = [[CBMutableService alloc] initWithType:MAGICLOCK_SERVICE_MAIN_UUID primary:YES];
            service.characteristics = @[heartbeatCharacteristic, writeCharacteristic, readCharacteristic];
            
            [self.manager addService:service];

        }
            break;
        case CBPeripheralManagerStatePoweredOff:
            break;
        case CBPeripheralManagerStateUnauthorized:
        case CBPeripheralManagerStateUnsupported:
        case CBPeripheralManagerStateResetting:
        case CBPeripheralManagerStateUnknown:
            break;
    }
}

- (void)peripheralManagerDidStartAdvertising:(CBPeripheralManager *)peripheral error:(nullable NSError *)error {
    if (error) {
        NSLog(@"application receive error : %@", [error localizedDescription]);
        exit(0);
    }
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didAddService:(CBService *)service error:(nullable NSError *)error {
    if (error) {
        NSLog(@"application receive error : %@", [error localizedDescription]);
        exit(0);
    }
    [self.manager startAdvertising:@{CBAdvertisementDataServiceUUIDsKey:@[MAGICLOCK_SERVICE_MAIN_UUID], CBAdvertisementDataLocalNameKey:[self deviceName]}];
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic {
    self.heartbeatCharacteristic = characteristic;
    [self startSendHeartbeatPacket];
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didUnsubscribeFromCharacteristic:(CBCharacteristic *)characteristic {
//    [self deviceDidDisconnect];
    [self.timeoutTimer invalidate];
    self.timeoutTimer = nil;
    self.timeoutTimer = [NSTimer scheduledTimerWithTimeInterval:6 repeats:NO block:^(NSTimer * _Nonnull timer) {
        if (self.heartbeatCharacteristic) {
            [self deviceDidDisconnect];
        }
    }];
}

- (void)deviceDidDisconnect {
    [self.timeoutTimer invalidate];
    self.timeoutTimer = nil;
    self.heartbeatCharacteristic = nil;
    self.phoneName = nil;
    self.realDistance = @"0米";
    self.makeSureFlag = 0;
    [[NCMacLockManager sharedInstance] lock];
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveReadRequest:(CBATTRequest *)request {
    
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveWriteRequests:(NSArray<CBATTRequest *> *)requests {
    if (requests.count != 1) {
        return;
    }
    
    if (self.heartbeatCharacteristic) {
        [self.timeoutTimer invalidate];
        self.timeoutTimer = nil;
        self.timeoutTimer = [NSTimer scheduledTimerWithTimeInterval:3 repeats:NO block:^(NSTimer * _Nonnull timer) {
            if (self.heartbeatCharacteristic) {
                [self deviceDidDisconnect];
            }
        }];
    }
    
    NSData *data = [requests firstObject].value;
    NSArray *array = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    if (array.count!=2) {
        return;
    }
    self.phoneName = [array objectAtIndex:0];
    NSNumber *RSSI = [array objectAtIndex:1];
    float d = NCDistWithRSSI(RSSI);
    NSLog(@"%.2f",d);
    self.realDistance = [NSString stringWithFormat:@"%.2f米", d];
    if (d>=self.lockDistance) {
        if (self.makeSureFlag<0) {
            self.makeSureFlag = 0;
        }
        if (self.makeSureFlag<NCPERIPHERALMANAGER_MAKESURECOUNT) {
            self.makeSureFlag++;
        }
    }
    else {
        if (self.makeSureFlag>0) {
            self.makeSureFlag = 0;
        }
        if (self.makeSureFlag>-NCPERIPHERALMANAGER_MAKESURECOUNT) {
            self.makeSureFlag--;
        }
    }
    if (self.makeSureFlag>=NCPERIPHERALMANAGER_MAKESURECOUNT) {
        [[NCMacLockManager sharedInstance] lock];
        self.makeSureFlag = 0;
    }
    else if (self.makeSureFlag<=-NCPERIPHERALMANAGER_MAKESURECOUNT) {
        [[NCMacLockManager sharedInstance] unlock];
    }
    [peripheral respondToRequest:[requests firstObject] withResult:CBATTErrorSuccess];
}

#pragma mark -

- (void)startSendHeartbeatPacket {
    if (!self.heartbeatCharacteristic) {
        return;
    }
    [self.manager updateValue:[@"active" dataUsingEncoding:NSUTF8StringEncoding] forCharacteristic:(CBMutableCharacteristic *)self.heartbeatCharacteristic onSubscribedCentrals:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self startSendHeartbeatPacket];
    });
}

@end
