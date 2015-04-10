//
//  ScanDeviceInfo.m
//  MYLE_BLE
//
//  Created by cxphong-macmini on 3/27/15.
//  Copyright (c) 2015 Mobiletuts. All rights reserved.
//

#import "ScanDeviceInfo.h"

@implementation ScanDeviceInfo

- (ScanDeviceInfo*)init: (CBPeripheral*)peripheral {
    self = [super init];
    if (self) {
        self.peripheral = peripheral;
    }
    
    return self;
}

- (CBPeripheral*)getPeripheral {
    return self.peripheral;
}

@end
