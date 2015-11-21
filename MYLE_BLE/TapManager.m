//
//  TapManager
//  Myle
//
//  Created by Sergey Slobodenyuk on 11.11.14.
//  Copyright (c) 2014 Myle Electronics Corp. All rights reserved.
//

#import "TapManager.h"
#import "TapServices.h"
#define CREDITBLE ((int) 423)


@interface TapManager()
- (void) notifyReadParameterListeners:(NSString*)parameterName intValue:(NSUInteger)intValue strValue:(NSString*) strValue;
- (void) trace:(NSString*)formatString, ...;
@end



@implementation TapManager
{
    CBCentralManager *_centralManager;
    
    CBPeripheral *_currentPeripheral;
    
    CBCharacteristic* _batteryLevelChrt;
    CBCharacteristic* _myleReadChrt;
    CBCharacteristic* _myleWriteChrt;
    
    NSString *_currentUUID;
    NSString *_currentPass;
    
    BOOL _isScanning;
    BOOL _isAuthenticating;
    BOOL _isConnected;
    
    NSMutableArray *_availableTaps;
    
    RECEIVE_MODE _receiveMode;
    
    NSMutableData *_audioBuffer;
    unsigned int _audioLength;
    unsigned int _audioRecordedTime;
    
    NSMutableData *_logBuffer;
    unsigned int _logLength;
    unsigned int _logCreatedTime;
    
    Boolean _isVerified;
    Boolean _isDropListSetVisible;
    Boolean _isDropListReadVisible;
    Boolean _isReceivingAudioFile;
    Boolean _isReceivingLogFile;
    
    NSMutableArray *_readParameterListeners;
    NSMutableArray *_traceListeners;
    
    float _progress;
}


// singleton pattern
+ (instancetype)shared {
    static TapManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}


+ (void)setup:(NSString*)uuid pass:(NSString*)pass
{
    TapManager *tap = [[self class] shared];
    [tap setInitUUIDAndPass:uuid pass:pass];
}


- (void)setInitUUIDAndPass:(NSString *)uuid pass:(NSString *)pass {
    _currentUUID = uuid;
    _currentPass = pass ? pass : DEFAULT_TAP_PASSWORD;
}


- (instancetype)init
{
    self = [super init];
    
    dispatch_queue_t centralQueue = dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0);
    
    _centralManager = [[CBCentralManager alloc] initWithDelegate:self
                                                           queue:centralQueue
                                                         options:@{ CBCentralManagerOptionRestoreIdentifierKey: @"myCentralManagerIdentifier" }];
    
    _currentPass = DEFAULT_TAP_PASSWORD;
    
    _readParameterListeners = [[NSMutableArray alloc] init];
    _traceListeners = [[NSMutableArray alloc] init];
    
    _availableTaps = [[NSMutableArray alloc] initWithCapacity:100];
    
    return self;
}


- (NSArray*)getAvailableTaps
{
    // for some reason scan takes sometimes too long
    // at least we can show connected device as first in the list
    NSMutableArray *taps = [[NSMutableArray alloc] initWithArray:[self isConnected] ? @[_currentPeripheral] : @[]];
    for (CBPeripheral *p in _availableTaps) {
        if (![taps containsObject:p]) {
            [taps addObject:p];
        }
    }
    return taps;
}


- (void)clearTapList
{
    [_availableTaps removeAllObjects];
    
    // notify subscribers about cleared peripheral list
    [self trace:@"Broadcasting about scan changes"];
    [[NSNotificationCenter defaultCenter] postNotificationName:kTapNtfn
                                                        object:nil
                                                      userInfo:@{ kTapNtfnType: @kTapNtfnTypeScan }];
}


- (BOOL)isConnected {
    return _isConnected;
}



// Clean up
- (void)cleanup {
    
    // See if we are subscribed to a characteristic on the peripheral
    if (_currentPeripheral.services != nil) {
        for (CBService *service in _currentPeripheral.services) {
            if (service.characteristics != nil) {
                for (CBCharacteristic *characteristic in service.characteristics) {
                    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:MYLE_READ_CHRT_UUID]] ||
                        [characteristic.UUID isEqual:[CBUUID UUIDWithString:BATTERY_LEVEL_UUID]]) {
                        if (characteristic.isNotifying) {
                            [_currentPeripheral setNotifyValue:NO forCharacteristic:characteristic];
                            return;
                        }
                    }
                }
            }
        }
    }
    
    [_centralManager cancelPeripheralConnection:_currentPeripheral];
}

- (void)centralManager:(CBCentralManager *)central willRestoreState:(NSDictionary<NSString *, id> *)dict
{
    [self trace:@"willRestoreState %@", dict];
    
    NSArray *peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey];
    
    [central connectPeripheral:peripherals[0] options:nil];
    
    [self trace:@"willRestoreState peripherals %@", peripherals];
}


- (void)disconnect {
    if (_currentPeripheral != nil) {
        [self forgetCurrent];
        [_centralManager cancelPeripheralConnection:_currentPeripheral];
        [self trace:@"Disconnecting from tap %@", _currentPeripheral.identifier.UUIDString];
    }
}


- (void)connect: (CBPeripheral*)peripheral pass:(NSString*)pass {
    _currentUUID = peripheral.identifier.UUIDString;
    _currentPass = pass;
    [_centralManager connectPeripheral:peripheral options:nil];
    [self trace:@"Connecting to tap %@", peripheral.identifier.UUIDString];
}


// Start scan
- (void)startScan {
    if (_isScanning) { return; }
    
    _isScanning = YES;
    
    [self clearTapList];
    
    NSArray *servicesTap = [NSArray arrayWithObjects: [CBUUID UUIDWithString:MYLE_SERVICE_UUID], [CBUUID UUIDWithString:BATTERY_SERVICE_UUID], nil];
    [_centralManager scanForPeripheralsWithServices:servicesTap options:@{ CBCentralManagerScanOptionAllowDuplicatesKey : @YES }];
    [self trace:@"Scan started"];
}

// Stop scan
- (void)stopScan {
    _isScanning = NO;
    
    [_centralManager stopScan];
    [self trace:@"Scan stopped"];
}


#pragma mark - CBCentralManagerDelegate Methods

// Scan peripherals
- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    switch (central.state)
    {
        case CBCentralManagerStateUnsupported:
            [self trace:@"BLE state: unsupported"];
            break;
            
        case CBCentralManagerStateUnauthorized:
            [self trace:@"BLE state: unauthorized"];
            break;
            
        case CBCentralManagerStatePoweredOff:
            [self trace:@"BLE state: powered off"];
            break;
            
        case CBCentralManagerStatePoweredOn:
            [self trace:@"BLE state: powered on"];
            [self startScan];
            break;
            
        case CBCentralManagerStateResetting:
            [self trace:@"BLE state: resetting"];
            break;
            
        default:
            [self trace:@"BLE state: unknown"];
            break;
    }
}


- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    // if devices is not in our list - add it and notify subscribers
    if ([_availableTaps containsObject:peripheral]) { return; }
    
    [_availableTaps addObject:peripheral];
        
    [self trace:@"Discovered peripheral %@ with advertisement data: %@", peripheral.identifier.UUIDString, advertisementData];
        
    // notify subscribers abuout new peripheral
    [self trace:@"Broadcasting about scan changes"];
    [[NSNotificationCenter defaultCenter] postNotificationName:kTapNtfn
                                                            object:nil
                                                          userInfo:@{ kTapNtfnType: @kTapNtfnTypeScan, kTapNtfnPeripheral: peripheral }];
    
    // check whether given peripheral is one that we were using last time
    if ([peripheral.identifier.UUIDString isEqualToString:_currentUUID] && !_isConnected) {
        // NOTE: for some reason auto-connection through retrievePeripheralsWithIdentifiers + connectPeripheral doesn't work
        // so we do autoconnections manually through scan
            
        // yes, this is the one! auto connect
        [self trace:@"Auto-connecting to previously used tap %@", peripheral.identifier.UUIDString];
        [self connect:peripheral pass:_currentPass];
    }
}


// Scan fail
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    [self trace:@"Failed to connect to tap %@ with error %@", peripheral.identifier.UUIDString, error];
    [self cleanup];
}


// Connect device success callback
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    [self stopScan];
    
    [self trace:@"Connected to tap %@]", peripheral.identifier.UUIDString];
    
    _currentPeripheral = peripheral;
    peripheral.delegate = self;
    
    NSArray * servicesTap = [NSArray arrayWithObjects: [CBUUID UUIDWithString:MYLE_SERVICE_UUID], [CBUUID UUIDWithString:BATTERY_SERVICE_UUID], nil];
    [peripheral discoverServices:servicesTap];
}


#pragma mark - CBPeripheralDelegate Methods

// List services
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    
    if (error) {
        [self trace:@"Error discovering services: %@", peripheral.identifier.UUIDString, error];
        [self cleanup];
        return;
    }
    [self trace:@"Discovering services: %@", peripheral.identifier.UUIDString];
    
    // List 2 characteristics
    NSArray * characteristics = [NSArray arrayWithObjects:
                                 [CBUUID UUIDWithString:MYLE_READ_CHRT_UUID],
                                 [CBUUID UUIDWithString:MYLE_WRITE_CHRT_UUID],
                                 [CBUUID UUIDWithString:BATTERY_LEVEL_UUID], nil];
    for (CBService *service in peripheral.services) {
        [peripheral discoverCharacteristics:characteristics forService:service];
    }
}


// List characteristics
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    if (error) {
        [self trace:@"Error discovering characteristics for service %@: %@", service.UUID.UUIDString, error];
        [self cleanup];
        return;
    }
    [self trace:@"Discovered characteristics for service %@", service.UUID.UUIDString];
    
    if ([[service UUID] isEqual:[CBUUID UUIDWithString:BATTERY_SERVICE_UUID]]) {
        for (CBCharacteristic *characteristic in service.characteristics) {
            if ([[characteristic UUID] isEqual:[CBUUID UUIDWithString:BATTERY_LEVEL_UUID]]) {
                _batteryLevelChrt = characteristic;
                [peripheral setNotifyValue:YES forCharacteristic:characteristic];
                break;
            }
        }
    } else if ([[service UUID] isEqual:[CBUUID UUIDWithString:MYLE_SERVICE_UUID]]) {
        for (CBCharacteristic *characteristic in service.characteristics) {
            if ([[characteristic UUID] isEqual:[CBUUID UUIDWithString:MYLE_READ_CHRT_UUID]]) {
                _myleReadChrt = characteristic;
                [peripheral setNotifyValue:YES forCharacteristic:characteristic];
            } else if ([[characteristic UUID] isEqual:[CBUUID UUIDWithString:MYLE_WRITE_CHRT_UUID]]) {
                _myleWriteChrt = characteristic;
                
                
            }
        }
    }
}


// Result of write to peripheral
- (void) peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error) {
        return [self trace:@"Error writing value for characteristic %@: %@", characteristic.UUID.UUIDString, error];
    }
}


// Update value from peripheral
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error) {
        return [self trace:@"Error updating value for characteristic %@: %@", characteristic.UUID.UUIDString, error];
    }
    
    // Readback of the battery level
    if (characteristic == _batteryLevelChrt) {
        [self readBatteryLevel:characteristic.value];
    }
    
    // Not correct characteristics
    if (characteristic != _myleReadChrt) {
        return;
    }
    
    /*********** RECEIVE PARAMETER VALUE ***************/
    if (!_isReceivingAudioFile && !_isReceivingLogFile) {
        if([self readParameter:characteristic.value]) { return; }
    }
    
    /*********** RECEIVE AUDIO FILE OR LOG FILE ********************/
    
    if (_receiveMode == RECEIVE_AUDIO_FILE) {
        [self handleRecieveAudioFile: characteristic.value
                      withPeripheral: peripheral
                    withChararistics: characteristic];
        
    } else if (_receiveMode == RECEIVE_LOG_FILE) {
        // Send back to peripheral number of bytes received.
        [self handleRecieveLogFile: characteristic.value
                    withPeripheral: peripheral
                  withChararistics: characteristic];
    }
}


// Convert Integer to NSData
-(NSData *) IntToNSData:(NSInteger)data
{
    Byte byteData[1] = { data & 0xff };
    return [NSData dataWithBytes:byteData length:1];
}


// Update notification from peripheral
- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error) {
        return [self trace:@"Error updating notification state for characteristic %@: %@", characteristic.UUID.UUIDString, error];
    }
    
    [self trace:@"Changed notification state to %@ on characteristic %@", characteristic.isNotifying ? @"NOTIFYING" : @"NOT NOTIFYING", characteristic.UUID.UUIDString];
    
    if (characteristic == _myleReadChrt && characteristic.isNotifying) {
        // Send password to board
        _isAuthenticating = YES;
    
        [self trace:@"Sending password: %@", _currentPass];
        [self sendPassword:_currentPass];
    }
}


// Disconnect peripheral
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    [self trace:@"Disconnected from tap %@", peripheral.identifier.UUIDString];
    
    if (error && error.code == 7) {
        // code 7 means "The specified device has disconnected from us."
        // so tap forces disconnection
        
        if (_isAuthenticating) {
            // in case of authentication it means that password was incorrect
            [self trace:@"Password doesn't match"];
        
            _isAuthenticating = NO;
        
            [self disconnect];
        
            // notify subscribers about bad password
            [self trace:@"Broadcasting about bad password"];
            [[NSNotificationCenter defaultCenter] postNotificationName:kTapNtfn
                                                            object:nil
                                                              userInfo:@{ kTapNtfnType: @kTapNtfnTypeAuthFailed }];
        } else {
            // otherwise - some unnessesary diconnection, try to reconnect
            [_centralManager connectPeripheral:peripheral options:nil];
            [self trace:@"Will connect to tap once it's available %@", _currentPeripheral.identifier.UUIDString];
        }
    }
    
    _currentPeripheral = nil;
    _progress = 0;
    _audioLength = 0;
    _isReceivingAudioFile = false;
    _logLength = 0;
    _isReceivingLogFile = false;
    _receiveMode = RECEIVE_NONE;
    _isConnected = NO;
    _isAuthenticating = NO;
    _myleReadChrt = nil;
    _myleWriteChrt = nil;
    _batteryLevelChrt = nil;
}


- (NSUInteger) getFromBytes:(Byte *) byteData {
    int dv = byteData[2]-48;
    int ch = byteData[1]-48;
    int ngh = byteData[0]-48;
    
    NSUInteger value = dv + ch*10 + ngh*100;
    
    return value;
}

- (Boolean) readBatteryLevel:(NSData *)data {
    Byte byteData[1] = { 0 };
    [data getBytes:byteData range:NSMakeRange(0, 1)];
    
    [self trace:@"Battery level received: %d", byteData[0]];
    [self notifyReadParameterListeners:@"BATTERY_LEVEL" intValue:byteData[0] strValue:nil];
    return true;
}


// Filter received data from device
- (Boolean) readParameter:(NSData *)data {
    Boolean ret = false;
    
    NSString* string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    // Audio header
    if (string == nil) return false;
    
    Byte byteData[3] = { 0 };
    
    if (!([string rangeOfString:@"5503RECLN"].location == NSNotFound))
    {
        [data getBytes:byteData range:NSMakeRange(@"5503RECLN".length, data.length-@"5503RECLN".length)];
        ret = true;
        [self notifyReadParameterListeners:@"RECLN" intValue:[self getFromBytes:byteData] strValue:nil];
    }
    else if (!([string rangeOfString:@"5503PAUSELEVEL"].location == NSNotFound))
    {
        [data getBytes:byteData range:NSMakeRange(@"5503PAUSELEVEL".length, data.length-@"5503PAUSELEVEL".length)];
        ret = true;
        [self notifyReadParameterListeners:@"PAUSELEVEL" intValue:[self getFromBytes:byteData] strValue:nil];
    }
    else if (!([string rangeOfString:@"5503PAUSELEN"].location == NSNotFound))
    {
        [data getBytes:byteData range:NSMakeRange(@"5503PAUSELEN".length, data.length-@"5503PAUSELEN".length)];
        ret = true;
        [self notifyReadParameterListeners:@"PAUSELEN" intValue:[self getFromBytes:byteData] strValue:nil];
    }
    else if (!([string rangeOfString:@"5503ACCELERSENS"].location == NSNotFound))
    {
        [data getBytes:byteData range:NSMakeRange(@"5503ACCELERSENS".length, data.length-@"5503ACCELERSENS".length)];
        ret = true;
        [self notifyReadParameterListeners:@"ACCELERSENS" intValue:[self getFromBytes:byteData] strValue:nil];
    }
    else if (!([string rangeOfString:@"5503BTLOC"].location == NSNotFound))
    {
        [data getBytes:byteData range:NSMakeRange(@"5503BTLOC".length, data.length-@"5503BTLOC".length)];
        ret = true;
        [self notifyReadParameterListeners:@"BTLOC" intValue:[self getFromBytes:byteData] strValue:nil];
    }
    else if (!([string rangeOfString:@"5503MIC"].location == NSNotFound))
    {
        [data getBytes:byteData range:NSMakeRange(@"5503MIC".length, data.length-@"5503MIC".length)];
        ret = true;
        [self notifyReadParameterListeners:@"MIC" intValue:[self getFromBytes:byteData] strValue:nil];
    }
    else if (!([string rangeOfString:@"5503VERSION"].location == NSNotFound))
    {
        Byte versionData[20] = { 0 };
        
        [data getBytes:versionData range:NSMakeRange(@"5503VERSION".length + 1, data.length - @"5503VERSION".length - 1)];
        ret = true;
        NSString *version = [NSString stringWithUTF8String:(const char *)versionData];
        [self trace:@"Device version received: %@", version];
        [self notifyReadParameterListeners:@"VERSION" intValue:0 strValue:version];
    }
    else if (!([string rangeOfString:@"CONNECTED"].location == NSNotFound))
    {
        _isAuthenticating = NO;
        _isConnected = YES;
        ret = true;
        
        // notify subscribers about connected peripheral
        [self trace:@"Broadcasting about connected tap"];
        [[NSNotificationCenter defaultCenter] postNotificationName:kTapNtfn
                                                            object:nil
                                                          userInfo:@{ kTapNtfnType: @kTapNtfnTypeConnected }];
        
        [self trace:@"Sending current time"];
        [self sendCurrentTime];
        
        return ret;
    } else if (!([string rangeOfString:@"5504"].location == NSNotFound)) {
        Byte buf[1] = { 0 };
        
        [data getBytes:buf range:NSMakeRange(4, 1)];
        
        if (buf[0] == '0') {
            _receiveMode = RECEIVE_AUDIO_FILE;
        } else if (buf[0] == '1') {
            _receiveMode = RECEIVE_LOG_FILE;
        }
        
        ret = true;
    } else if (!([string rangeOfString:@"5503UUID"].location == NSNotFound)) {
        Byte UUID[20] = { 0 };
        
        [data getBytes:UUID range:NSMakeRange(@"5503UUID".length, data.length - @"5503UUID".length)];
        ret = true;
        NSString *UUIDStr = [NSString stringWithUTF8String:(const char *)UUID];
        [self trace:@"Bluetooth mac address: %@", UUIDStr];
        [self notifyReadParameterListeners:@"UUID" intValue:0 strValue:UUIDStr];
        
    }
    return ret;
}


- (void)handleRecieveAudioFile: (NSData*)data
                withPeripheral: (CBPeripheral*)peripheral
              withChararistics: (CBCharacteristic*)characteristic {
    
    static CFTimeInterval startTime = 0;
    
    if (_audioLength == 0) // First packet
    {
        unsigned int ml;
        
        [characteristic.value getBytes:&ml length:4];
        [self trace:[NSString stringWithFormat:@"Read record metadata: metadata length = %d", ml]];
        
        [characteristic.value getBytes:&_audioLength range:NSMakeRange(4, 4)];
        [self trace:[NSString stringWithFormat:@"Read record metadata: audio length = %d", _audioLength]];
        
        [characteristic.value getBytes:&_audioRecordedTime range:NSMakeRange(8, 4)];
        
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:TimeFormat];
        [self trace:[NSString stringWithFormat:@"Read record metadata: record time = %@", [formatter stringFromDate:[self getDateFromInt:_audioRecordedTime]]]];
        
        [self trace:@"Receiving audio data..."];
        
        _audioBuffer = [[NSMutableData alloc] init];
        _isReceivingAudioFile = true;
        _progress = 0;
        
        NSInteger numBytes = CREDITBLE;
        Byte byteData[2] = { numBytes & 0xff, numBytes >> 8 };
        NSData *data2 = [NSData dataWithBytes:byteData length:2];
        
        [_currentPeripheral writeValue:data2 forCharacteristic:_myleWriteChrt type:CBCharacteristicWriteWithoutResponse];
        
        startTime = CACurrentMediaTime();
        
    }
    else if (_audioBuffer.length < _audioLength)
    {
        static NSInteger numBytesTransfered = 0;
        
        [_audioBuffer appendData:characteristic.value];
        
        float currentProgress = (float)_audioBuffer.length / (float)_audioLength;
        if (fabsf(currentProgress - _progress) >= PROGRESS_LOG_DELTA || _audioBuffer.length == _audioLength) {
            _progress = currentProgress;
            [self trace:@"Received %d%%", (int)(_progress * 100.0f)];
        }
        
        if (_audioBuffer.length >= _audioLength)
        {
            CFTimeInterval elapsedTime = CACurrentMediaTime() - startTime;
            
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            [formatter setDateFormat:RecordFileFormat];
            NSString *fileName = [NSString stringWithFormat:@"%@.wav", [formatter stringFromDate:[self getDateFromInt:_audioRecordedTime]]];
            NSString *filePath = [DocumentsPath() stringByAppendingPathComponent:fileName];
            
            [_audioBuffer writeToFile:filePath atomically:YES];
            
            [self trace:[NSString stringWithFormat:@"Audio saved to %@", fileName]];
            [self trace:[NSString stringWithFormat:@"Transfer Speed %d B/s", (int)(_audioLength/elapsedTime)]];
            
            // reset
            _audioLength = 0;
            _progress = 0;
            _isReceivingAudioFile = false;
            _receiveMode = RECEIVE_NONE;
            
            // notify subscribers about new file appearence
            [self trace:@"Broadcsating about received file"];
            [[NSNotificationCenter defaultCenter] postNotificationName:kTapNtfn
                                                                object:nil
                                                              userInfo:@{ kTapNtfnType: @kTapNtfnTypeFile, kTapNtfnFilePath: filePath }];
        }
        else{
            
            numBytesTransfered += characteristic.value.length;
            
            NSInteger numBytes = CREDITBLE;
            if(_audioLength - _audioBuffer.length < CREDITBLE)
            {
                numBytes = _audioLength - _audioBuffer.length;
            }
            
            if(numBytesTransfered >= numBytes)
            {
                numBytesTransfered = 0;
                Byte byteData[2] = { numBytes & 0xff, numBytes >> 8 };
                NSData *data2 = [NSData dataWithBytes:byteData length:2];
                [_currentPeripheral writeValue:data2 forCharacteristic:_myleWriteChrt type:CBCharacteristicWriteWithoutResponse];
            }
        }
    }
}


- (void)handleRecieveLogFile: (NSData*)data
              withPeripheral: (CBPeripheral*)peripheral
            withChararistics: (CBCharacteristic*)characteristic {
    
    static NSInteger numBytesTransfered = 0;
    static unsigned int fileLength = 0;
    
    // perform some action
    if (_logLength == 0) // First packet
    {
        unsigned int ml;
        
        [data getBytes:&ml length:4];
        [self trace:[NSString stringWithFormat:@"Log metadata: metadata length = %d", ml]];
        
        [data getBytes:&_logLength range:NSMakeRange(4, 4)];
        [self trace:[NSString stringWithFormat:@"Log metadata: log length = %d", _logLength]];
        
        [data getBytes:&_logCreatedTime range:NSMakeRange(8, 4)];
        
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:TimeFormat];
        [self trace:[NSString stringWithFormat:@"Log metadata: created time = %@", [formatter stringFromDate:[self getDateFromInt:_logCreatedTime]]]];
        
        [self trace:@"Receiving log data ..."];
        
        _logBuffer = [[NSMutableData alloc] init];
        _isReceivingLogFile = true;
        NSInteger numBytes = 235;
        NSData *data = [self IntToNSData:numBytes];
        [_currentPeripheral writeValue:data forCharacteristic:_myleWriteChrt type:CBCharacteristicWriteWithoutResponse];
        
    }
    else if (_logBuffer.length < _logLength)
    {
        [_logBuffer appendData:data];
        
        if (_logBuffer.length >= _logLength)
        {
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            [formatter setDateFormat:RecordFileFormat];
            NSString *fileName = [NSString stringWithFormat:@"%@.log", [formatter stringFromDate:[self getDateFromInt:_logCreatedTime]]];
            
            NSString *filePath = [DocumentsPath() stringByAppendingPathComponent:fileName];
            [_logBuffer writeToFile:filePath atomically:YES];
            
            [self trace:[NSString stringWithFormat:@"Log saved to %@", fileName]];
            
            // Reset
            _logLength = 0;
            _isReceivingLogFile = false;
            _receiveMode = RECEIVE_NONE;
        }
        else{
            
            numBytesTransfered += characteristic.value.length;
            fileLength += numBytesTransfered;
            
            NSInteger numBytes = 235;
            if(_logLength - _logBuffer.length < 235)
            {
                numBytes = _logLength - _logBuffer.length;
            }
            
            if(numBytesTransfered >= numBytes)
            {
                numBytesTransfered = 0;
                NSData *data = [self IntToNSData:numBytes];
                [_currentPeripheral writeValue:data forCharacteristic:_myleWriteChrt type:CBCharacteristicWriteWithoutResponse];
            }
        }
    }
}


- (void) sendParameter: (NSData *) data
{
    [_currentPeripheral writeValue:data forCharacteristic:_myleWriteChrt type:CBCharacteristicWriteWithoutResponse];
}


- (void)sendPassword:(NSString*)password {
    NSData *data;
    NSData *passData = [password dataUsingEncoding:NSUTF8StringEncoding];
    
    Byte byteData[5] = { '5', '5', '0', '1', password.length & 0xff };
    
    data = [NSData dataWithBytes:byteData length:5];
    
    NSMutableData *concatenatedData = [[NSMutableData alloc] init];
    [concatenatedData appendData:data];
    [concatenatedData appendData:passData];
    
    [self sendParameter:concatenatedData];
}


- (void) sendCurrentTime {
    // Sync time to board
    NSCalendar *calendar = [NSCalendar currentCalendar];
    calendar.timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
    NSDateComponents *components = [calendar components:(NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond | NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear) fromDate:[NSDate date]];
    NSInteger hour, minute, second, day, month, year;
    
    hour = [components hour];
    minute = [components minute];
    second = [components second];
    day = [components day];
    month = [components month];
    year = [components year];
    
    NSData *data = [[NSData alloc] init];
    Byte byteData[10] = { '5', '5', '0', '0', second & 0xff, minute & 0xff, hour & 0xff, day & 0xff, month & 0xff, (year - 2000) & 0xff };
    
    data = [NSData dataWithBytes:byteData length:10];
    
    [self sendParameter:data];
}


/************ UPDATE PARAMETER ****************/


NSMutableData* getParameterDataFromString(NSString *p, NSString *v) {
    NSString *s = [NSString stringWithFormat:@"%@%@", p, v];
    Byte byteData[s.length];
    for (int i = 0; i < s.length; i ++) {
        byteData[i] = [s characterAtIndex:i];
    }
    return [NSMutableData dataWithBytes:byteData length:s.length];
}


// Update Parameter RECLN
- (void)sendWriteRECLN: (NSString *)value {
    [self sendParameter:getParameterDataFromString(@"5502RECLN", value)];
}

// Update Parameter PAUSE_LEVEL
- (void)sendWritePAUSELEVEL: (NSString *)value {
    [self sendParameter:getParameterDataFromString(@"5502PAUSELEVEL", value)];
}

// Update Parameter PAUSE_LEN
- (void)sendWritePAUSELEN: (NSString *)value{
    [self sendParameter:getParameterDataFromString(@"5502PAUSELEN", value)];
}

// Update Parameter ACCELER_SENS
- (void)sendWriteACCELERSENS:(NSString *)value {
    [self sendParameter:getParameterDataFromString(@"5502ACCELERSENS", value)];
}

// Update parameter MIC
- (void)sendWriteMIC:(NSString *)value {
    [self sendParameter:getParameterDataFromString(@"5502MIC", value)];
}

// Update parameter BTLOC
- (void)sendWriteBTLOC:(NSString *)value {
    [self sendParameter:getParameterDataFromString(@"5502BTLOC", value)];
}

- (void)sendWritePASSWORD:(NSString *)value {
    _currentPass = value;
    
    unichar passLength = { value.length & 0xff };
    
    NSMutableData *data = getParameterDataFromString(@"5502PASS", [NSString stringWithCharacters:&passLength length:1]);
    
    [data appendData:[value dataUsingEncoding:NSUTF8StringEncoding]];
    
    [self sendParameter:data];
}
/************ END UPDATE PARAMETER ****************/

/************ READ PARAMETER ****************/

- (void)sendReadRECLN {
    [self sendParameter:getParameterDataFromString(@"5503RECLN", @"")];
}

- (void)sendReadBTLOC {
    [self sendParameter:getParameterDataFromString(@"5503BTLOC", @"")];
}

- (void)sendReadUUID {
    [self sendParameter:getParameterDataFromString(@"5503UUID", @"")];
}

- (void)sendReadPAUSELEVEL {
    [self sendParameter:getParameterDataFromString(@"5503PAUSELEVEL", @"")];
}

- (void)sendReadPAUSELEN {
    [self sendParameter:getParameterDataFromString(@"5503PAUSELEN", @"")];
}

- (void)sendReadACCELERSENS {
    [self sendParameter:getParameterDataFromString(@"5503ACCELERSENS", @"")];
}

- (void)sendReadMIC {
    [self sendParameter:getParameterDataFromString(@"5503MIC", @"")];
}

- (void)sendReadVERSION {
    [self sendParameter:getParameterDataFromString(@"5503VERSION", @"")];
}

- (void)sendReadBATTERY_LEVEL {
    [_currentPeripheral readValueForCharacteristic:_batteryLevelChrt];
}

/************ END READ PARAMETER ****************/


- (NSString*) getCurrentTapUUID
{
    return _currentUUID;
}


- (NSString*) getCurrentTapPassword {
    return _currentPass;
}


- (void)forgetCurrent {
    _currentUUID = nil;
    _currentPass = nil;
}


- (void) addParameterReadListener:(ReadParameterListener)listener
{
    if (listener && ![_readParameterListeners containsObject:listener])
    {
        [_readParameterListeners addObject:listener];
    }
}


- (void) removeParameterReadListener:(ReadParameterListener)listener
{
    [_readParameterListeners removeObject:listener];
}


- (void) notifyReadParameterListeners:(NSString*)parameterName intValue:(NSUInteger)intValue strValue:(NSString*) strValue
{
    for (ReadParameterListener listener in _readParameterListeners) {
        listener(parameterName, intValue, strValue);
    }
}


- (void) addTraceListener:(TraceListener)listener
{
    if (listener != nil && ![_traceListeners containsObject:listener])
    {
        [_traceListeners addObject:listener];
    }
}


- (void) trace:(NSString*)formatString, ...
{
    if (_traceListeners.count == 0) { return; }
    
    va_list args;
    va_start(args, formatString);
    NSString *message = [[NSString alloc] initWithFormat:formatString arguments:args];
    va_end(args);
    
    for (TraceListener listener in _traceListeners) {
        if (listener) {
            listener(message);
        }
    }
}


- (CBPeripheral*)getPeripheralByUUID:(NSString*)uuid
{
    for (CBPeripheral *p in _availableTaps) {
        if ([p.identifier.UUIDString isEqualToString:uuid]) {
            return p;
        }
    }
    return nil;
}


/****** UTILITY FUNCTIONS *************/


-(NSDate*)getDateFromInt:(unsigned int)l
{
    NSDateComponents *c = [[NSCalendar currentCalendar] components:NSUIntegerMax fromDate:[NSDate date]];
    [c setSecond:((l & 0x1f) * 2)];
    l = l >> 5;
    
    [c setMinute:l & 0x3f];
    l = l >> 6;
    
    [c setHour:l & 0x1f];
    l = l >> 5;
    
    [c setDay:l & 0x1f];
    l = l >> 5;
    
    [c setMonth:l & 0xf];
    l = l >> 4;
    
    [c setYear:(l & 0x7f)];
    
    NSCalendar *cal = [NSCalendar currentCalendar];
    return [cal dateFromComponents:c];
}



@end