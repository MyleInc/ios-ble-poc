//
//  TapManager
//  Myle
//
//  Created by Sergey Slobodenyuk on 11.11.14.
//  Copyright (c) 2014 Myle Electronics Corp. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "Globals.h"


typedef void (^ReadParameterListener)(NSString*, NSUInteger, NSString*);
typedef void (^TraceListener)(NSString*);


#define DEFAULT_TAP_PASSWORD            @"1234abcd"

#define kTapNtfn                        @"TapNotification"
#define kTapNtfnType                    @"Type"
#define kTapNtfnFilePath                @"FilePath" // path to a recieved file
#define kTapNtfnMAC                     @"MAC"      // MAC address of a TAP
#define kTapNtfnPeripheral              @"Peripheral"

#define kTapNtfnTypeScan                1 // indicates new devices are discovered
#define kTapNtfnTypeConnected           2 // connection status
#define kTapNtfnTypeFile                3 // recieved a file
#define kTapNtfnTypeAuthFailed          4 // bad password

#define PROGRESS_LOG_DELTA              0.1f


@interface TapManager : NSObject <CBCentralManagerDelegate, CBPeripheralDelegate>

// Sets up tap manager with TAP UUID and password from last session
+ (void)setup:(NSString*)uuid pass:(NSString*)pass;

// Seturns shared TapManager instance
+ (instancetype)shared;

// Returns array of available taps
- (NSArray*)getAvailableTaps;

// Returns UUID of current or last connected TAP
- (NSString*)getCurrentTapUUID;

// Returns password of current or last connected TAP
- (NSString*)getCurrentTapPassword;

// Returns MAC of current or last connected TAP
- (NSString*)getCurrentTapMAC;

// Forgets current TAP UUID and password
- (void)forgetCurrent;

// Retunrns YES if a TAP is connected
- (BOOL)isConnected;

// Looks up for an available peripheral with given UUID
- (CBPeripheral*)getPeripheralByUUID:(NSString*)uuid;

// Returns name of given peripheral
- (NSString*)getPeripheralName:(CBPeripheral*)peripheral;

// Connects to a peripheral with given pass
- (void)connect: (CBPeripheral*)peripheral pass:(NSString*)pass;

// Disconnects currently connected peripheral
- (void)disconnect;

// Sends a command to tap to make some noise
- (void)locate;

// Resets tap to factory defaults
- (void)resetToFactoryDefaults;

// Start scan
- (void)startScan;

// Stop scan
- (void)stopScan;

// Adds a listener for parameter read notification
- (void)addParameterReadListener:(ReadParameterListener)listener;

// Adds a listener for parameter read notification
- (void)removeParameterReadListener:(ReadParameterListener)listener;

// Adds a listener for trace messafes
- (void)addTraceListener:(TraceListener)listener;

- (void)sendWriteRECLN:(Byte)value;
- (void)sendWriteMIC:(Byte)value;
- (void)sendWritePAUSELEVEL:(Byte)value;
- (void)sendWritePAUSELEN:(Byte)value;
- (void)sendWriteACCELERSENS:(Byte)value;
- (void)sendWritePASSWORD:(NSString *)value;

- (void)sendReadRECLN;
- (void)sendReadMIC;
- (void)sendReadPAUSELEVEL;
- (void)sendReadPAUSELEN;
- (void)sendReadACCELERSENS;
- (void)sendReadPASSWORD;
- (void)sendReadBATTERY_LEVEL;
- (void)sendReadFirmwareVersion;
- (void)sendReadHardwareVersion;

@end
