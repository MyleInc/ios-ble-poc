//
//  TapManager
//  Myle
//
//  Created by Sergey Slobodenyuk on 11.11.14.
//  Copyright (c) 2014 Myle Electronics Corp. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>


typedef void (^Listener)(NSString*, NSUInteger, NSString*);


#define DEFAULT_TAP_PASSWORD            @"1234abcd"
#define kFileReceivedByBluetooth        @"FileReceivedByBluetooth"
#define kFilePath                       @"FilePath"

#define kScanNotification               @"ScanNotification"
#define kPeripheral                     @"Peripheral"


@interface TapManager : NSObject <CBCentralManagerDelegate, CBPeripheralDelegate>

+ (void)setup;

+ (instancetype)shared;

- (NSArray*)getAvailableTaps;

- (NSString*)getCurrentTapUUID;

- (NSString*)getCurrentPassword;

- (void)connect : (CBPeripheral*)peripheral;

- (void)addParameterReadListener:(Listener)listener;

- (void)sendWriteRECLN:(NSString *)value;
- (void)sendWritePAUSELEVEL:(NSString *)value;
- (void)sendWritePAUSELEN:(NSString *)value;
- (void)sendWriteACCELERSENS:(NSString *)value;
- (void)sendWriteMIC:(NSString *)value;
- (void)sendWritePASSWORD:(NSString *)value;

- (void)sendReadRECLN;
- (void)sendReadBTLOC;
- (void)sendReadPAUSELEVEL;
- (void)sendReadPAUSELEN;
- (void)sendReadACCELERSENS;
- (void)sendReadMIC;
- (void)sendReadVERSION;

@end
