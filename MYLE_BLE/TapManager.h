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
#define kTapNtfnPeripheral              @"Peripheral"

#define kTapNtfnTypeScan                1 // indicates new devices are discovered
#define kTapNtfnTypeStatus              2 // connection status
#define kTapNtfnTypeFile                3 // recieved a file


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

// Retunrns YES if a TAP is connected
- (BOOL)isConnected;

// Looks up for an available peripheral with given UUID
- (CBPeripheral*)getPeripheralByUUID:(NSString*)uuid;

// Connects to a peripheral with given pass
- (void)connect: (CBPeripheral*)peripheral pass:(NSString*)pass;

// Adds a listener for parameter read notification
- (void)addParameterReadListener:(ReadParameterListener)listener;

// Adds a listener for trace messafes
- (void)addTraceListener:(TraceListener)listener;

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