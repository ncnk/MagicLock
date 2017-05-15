//
//  PublicMacro.h
//  MagicLock
//
//  Created by 程启航 on 2017/5/15.
//
//

#ifndef PublicMacro_h
#define PublicMacro_h


#define MAGICLOCK_SERVICE_MAIN_UUID                [CBUUID UUIDWithString:@"AAAAAAAA-AAAA-AAAA-AAAA-100000000000"]

#define MAGICLOCK_CHARACTERISTIC_HEARTBEAT_UUID    [CBUUID UUIDWithString:@"AAAAAAAA-AAAA-AAAA-AAAA-100000000001"]
#define MAGICLOCK_CHARACTERISTIC_WRITE_UUID        [CBUUID UUIDWithString:@"AAAAAAAA-AAAA-AAAA-AAAA-100000000002"]
#define MAGICLOCK_CHARACTERISTIC_READ_UUID         [CBUUID UUIDWithString:@"AAAAAAAA-AAAA-AAAA-AAAA-100000000003"]


/**
 根据 RSSI 计算距离

 @param RSSI 信号强度。      NSNumber 类型
 @return 距离。             double 型
 */
#define NCDistWithRSSI(RSSI)    pow(10.0, (labs([(RSSI) integerValue])-59)/(10*1.5))


#endif /* PublicMacro_h */
