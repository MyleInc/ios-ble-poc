//
//  ScanDeviceInfo.h
//  MYLE_BLE
//
//  Created by cxphong-macmini on 3/27/15.
//  Copyright (c) 2015 Mobiletuts. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

@interface ScanDeviceInfo : NSObject

@property CBPeripheral *peripheral;

- (CBPeripheral*)getPeripheral;
- (ScanDeviceInfo*)init: (CBPeripheral*)peripheral;

@end
