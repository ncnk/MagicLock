//
//  NCCentralManager.m
//  MagicLock
//
//  Created by 程启航 on 2017/4/6.
//
//

#import "NCCentralManager.h"
#import <CoreBluetooth/CoreBluetooth.h>
#import <UIKit/UIKit.h>
#import "PublicMacro.h"

@interface NCCentralManager ()<CBCentralManagerDelegate, CBPeripheralDelegate>

@property (nonatomic, strong) CBCentralManager *centralManager;

@property (nonatomic, strong) CBPeripheral *peripheral;

@property (nonatomic, strong) CBCharacteristic *writeCharacteristic;
@property (nonatomic, strong) CBCharacteristic *readCharacteristic;

@end

@implementation NCCentralManager

static NCCentralManager *_bluetoothManager = nil;
+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _bluetoothManager = [NCCentralManager new];
    });
    return _bluetoothManager;
}


- (void)start {
    if (!self.centralManager) {
        self.centralManager = [[CBCentralManager alloc] initWithDelegate:self
                                                                   queue:nil
                                                                 options:nil];
    }
}

#pragma mark - CBCentralManagerDelegate

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    switch (central.state) {
        case CBManagerStatePoweredOn:
        {
            [self.centralManager scanForPeripheralsWithServices:@[MAGICLOCK_SERVICE_MAIN_UUID] options:@{CBCentralManagerScanOptionAllowDuplicatesKey:@1}];
            self.centralManager.delegate = self;
        }
            break;
        case CBManagerStatePoweredOff:
            break;
        case CBManagerStateUnauthorized:
        case CBManagerStateUnsupported:
        case CBManagerStateResetting:
        case CBManagerStateUnknown:
            break;
    }
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *, id> *)advertisementData RSSI:(NSNumber *)RSSI {
    NSArray<CBUUID *> *uuids = [advertisementData objectForKey:CBAdvertisementDataServiceUUIDsKey];
    if (![[uuids firstObject].UUIDString isEqualToString:MAGICLOCK_SERVICE_MAIN_UUID.UUIDString] ||
        !peripheral.name) {
        return;
    }
    self.peripheral = peripheral;
    
    [self.centralManager stopScan];

    [self.centralManager connectPeripheral:self.peripheral options:nil];
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    self.peripheral.delegate = self;
    [self.peripheral discoverServices:@[MAGICLOCK_SERVICE_MAIN_UUID]];
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error {
    [self restartScan];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error {
    [self restartScan];
}

- (void)restartScan {
    if (self.peripheral.state == CBPeripheralStateConnecting ||
        self.peripheral.state == CBPeripheralStateConnected) {
        [self.centralManager cancelPeripheralConnection:self.peripheral];
    }
    self.peripheral = nil;
    self.writeCharacteristic = nil;
    self.readCharacteristic = nil;
    [self.centralManager scanForPeripheralsWithServices:@[MAGICLOCK_SERVICE_MAIN_UUID] options:@{CBCentralManagerScanOptionAllowDuplicatesKey:@1}];
}

#pragma mark - CBPeripheralDelegate

- (void)peripheral:(CBPeripheral *)peripheral didModifyServices:(NSArray<CBService *> *)invalidatedServices {
    [self restartScan];
}

- (void)peripheral:(CBPeripheral *)peripheral didReadRSSI:(NSNumber *)RSSI error:(nullable NSError *)error {
    float d = NCDistWithRSSI(RSSI);
    NSLog(@"%.2f",f);
    [self.peripheral writeValue:[NSKeyedArchiver archivedDataWithRootObject:@[[UIDevice currentDevice].name, RSSI]] forCharacteristic:self.writeCharacteristic type:CBCharacteristicWriteWithResponse];
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(nullable NSError *)error {
    for (CBService *service in peripheral.services) {
        [peripheral discoverCharacteristics:@[MAGICLOCK_CHARACTERISTIC_HEARTBEAT_UUID,
                                              MAGICLOCK_CHARACTERISTIC_WRITE_UUID,
                                              MAGICLOCK_CHARACTERISTIC_READ_UUID
                                              ] forService:service];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(nullable NSError *)error {
    if (error) {
        return;
    }
    for (CBCharacteristic *characteristic in service.characteristics) {
        switch (characteristic.properties) {
            case CBCharacteristicPropertyNotify:
                [peripheral setNotifyValue:YES forCharacteristic:characteristic];
                break;
            case CBCharacteristicPropertyWrite:
                self.writeCharacteristic = characteristic;
                break;
            case CBCharacteristicPropertyRead:
                self.readCharacteristic = characteristic;
                break;
            default:
                break;
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error  {
    [peripheral readRSSI];
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error {
    
}

#pragma mark -

- (float)calcDistByRSSI:(NSInteger)rssi
{
    float power = (labs(rssi)-59)/(10*1.5);
    return pow(10, power);
}
@end
