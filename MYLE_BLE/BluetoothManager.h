//
//  BluetoothManager.h
//  MYLE_BLE
//
//  Created by cxphong-macmini on 3/27/15.
//  Copyright (c) 2015 Mobiletuts. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "ScanDeviceInfo.h"

// DELEGATE
@protocol ParameterDelegate <NSObject>
- (void) didReceiveRECLN: (NSUInteger) value;
- (void) didReceivePAUSE_LEVEL: (NSUInteger) value;
- (void) didReceivePAUSE_LEN: (NSUInteger) value;
- (void) didReceiveACCELER_SENS: (NSUInteger) value;
- (void) didReceiveMIC: (NSUInteger) value;
- (void) didReceiveBTLOC: (NSUInteger) value;
- (void) didReceiveVERSION: (NSString *) value;
@end

@protocol ScanDelegate <NSObject>
- (void)didScanNewDevice: (ScanDeviceInfo*)device;
@end

@protocol LogDelegate <NSObject>
- (void)log: (NSString*)message;
@end

@interface BluetoothManager : NSObject< CBCentralManagerDelegate, CBPeripheralDelegate>
+ (BluetoothManager*)createInstance;
+ (void)destroyInstance;
- (void) disconnect;
- (void)connect: (CBPeripheral*)peripheral;
- (void)setInitialPassword:(NSString *)password;
- (void)send: (NSData*)data;
- (NSString*)getPeripheralUUID;

@property (assign) id<ParameterDelegate> parameterDelegate;
@property (assign) id<ScanDelegate> scanDelegate;
@property (assign) id<LogDelegate> logDelegate;

@end
