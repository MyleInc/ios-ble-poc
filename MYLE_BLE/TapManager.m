//
//  TapManager
//  Myle
//
//  Created by Sergey Slobodenyuk on 11.11.14.
//  Copyright (c) 2014 Myle Electronics Corp. All rights reserved.
//

#import "TapManager.h"
#import "TapServices.h"



@interface TapManager()
    - (void) notifyReadParameterListeners:(NSString*)parameterName intValue:(NSUInteger)intValue strValue:(NSString*) strValue;
    - (void) trace:(NSString*)formatString, ...;
@end



@implementation TapManager
{
    CBCentralManager *_centralManager;
    
    CBPeripheral *_currentPeripheral;
    
    NSString *_currentUUID;
    NSString *_currentPass;
    
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
    
    _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    
    _currentPass = DEFAULT_TAP_PASSWORD;
    
    _readParameterListeners = [[NSMutableArray alloc] init];
    _traceListeners = [[NSMutableArray alloc] init];
    
    _availableTaps = [[NSMutableArray alloc] initWithCapacity:100];
    
    return self;
}


- (NSArray*)getAvailableTaps
{
    return _availableTaps;
}


- (void)clearTapList
{
    [_availableTaps removeAllObjects];
    
    // notify subscribers about cleared peripheral list
    [[NSNotificationCenter defaultCenter] postNotificationName:kTapNtfn
                                                        object:nil
                                                      userInfo:@{ kTapNtfnType: @kTapNtfnTypeScan }];
}


- (BOOL)isConnected {
    return _isConnected;
}


// Scan periphrals with specific service UUID
- (void)scanPeripherals {
    [self clearTapList];
    
    [_centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:SERVICE_UUID]] options:@{ CBCentralManagerScanOptionAllowDuplicatesKey : @NO }];
    
    [self trace:@"Scan started"];
}


// Clean up
- (void)cleanup {
    
    // See if we are subscribed to a characteristic on the peripheral
    if (_currentPeripheral.services != nil) {
        for (CBService *service in _currentPeripheral.services) {
            if (service.characteristics != nil) {
                for (CBCharacteristic *characteristic in service.characteristics) {
                    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:CHARACTERISTIC_UUID_TO_READ]] ||
                        [characteristic.UUID isEqual:[CBUUID UUIDWithString:CHARACTERISTIC_UUID_TO_WRITE]]) {
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


- (void)disconnect {
    if (_currentPeripheral != nil && _currentPeripheral.state == CBPeripheralStateConnecting) {
        [_centralManager cancelPeripheralConnection:_currentPeripheral];
        [self trace:@"Disconnecting from tap %@", _currentPeripheral.identifier.UUIDString];
    }
}


- (void)connect: (CBPeripheral*)peripheral pass:(NSString*)pass {
    _currentPeripheral = peripheral;
    _currentUUID = peripheral.identifier.UUIDString;
    _currentPass = pass;
    [_centralManager connectPeripheral:_currentPeripheral options:nil];
    [self trace:@"Connecting to tap %@", _currentPeripheral.identifier.UUIDString];
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
            [self scanPeripherals];
            break;
            
        case CBCentralManagerStateResetting:
            [self trace:@"BLE state: resetting"];
            break;
            
        default:
            [self trace:@"BLE state: unknown"];
            break;
    }
}


//Scan success
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    
    [self trace:@"Discovered peripheral %@ with advertisement data: %@", peripheral.identifier.UUIDString, advertisementData];
    
    // if devices is not in our list - add it and notify subscribers
    if (![_availableTaps containsObject:peripheral]) {
        [_availableTaps addObject:peripheral];
        
        // notify subscribers abuout new peripheral
        [[NSNotificationCenter defaultCenter] postNotificationName:kTapNtfn
                                                            object:nil
                                                          userInfo:@{ kTapNtfnType: @kTapNtfnTypeScan, kTapNtfnPeripheral: peripheral }];
    }
    
    // check whether given peripheral is one that we were using last time
    if ([peripheral.identifier.UUIDString isEqualToString:_currentUUID]) {
        // yes, this is the one! auto connect
        [self trace:@"Auto-connecting to previously used tap %@", peripheral.identifier.UUIDString];
        [self connect:peripheral pass:_currentPass];
    }
}


// Scan fail
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    [self trace:@"Failed to connect to tap %@", peripheral.identifier.UUIDString];
    [self cleanup];
}


// Connect device success callback
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    [_centralManager stopScan];
    
    [self trace:@"Connected to tap %@, stopped scanning", peripheral.identifier.UUIDString];
    
    _isConnected = YES;
    
    peripheral.delegate = self;
    
    [peripheral discoverServices:@[[CBUUID UUIDWithString:SERVICE_UUID]]];
    
    // notify subscribers about connected peripheral
    [[NSNotificationCenter defaultCenter] postNotificationName:kTapNtfn
                                                        object:nil
                                                      userInfo:@{ kTapNtfnType: @kTapNtfnTypeStatus }];
}


#pragma mark - CBPeripheralDelegate Methods

// List services
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    
    if (error) {
        [self trace:@"Error discovering services: %@", peripheral.identifier.UUIDString, error];
        [self cleanup];
        return;
    }
    
    // List 2 characteristics
    NSArray * characteristics = [NSArray arrayWithObjects: [CBUUID UUIDWithString:CHARACTERISTIC_UUID_TO_READ], [CBUUID UUIDWithString:CHARACTERISTIC_UUID_TO_WRITE], [CBUUID UUIDWithString:CHARACTERISTIC_UUID_CONFIG], nil];
    
    for (CBService *service in peripheral.services) {
        [peripheral discoverCharacteristics:characteristics forService:service];
    }
}


- (NSData *)makeKey:(NSString *)password {
    NSData *data;
    NSData *passData = [_currentPass dataUsingEncoding:NSUTF8StringEncoding];
    
    Byte byteData[5] = { '5', '5', '0', '1', password.length & 0xff };
    
    data = [NSData dataWithBytes:byteData length:5];
    
    NSMutableData *concatenatedData = [[NSMutableData alloc] init];
    [concatenatedData appendData:data];
    [concatenatedData appendData:passData];
    
    return concatenatedData;
}


// List chacracteristics
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    if (error) {
        [self trace:@"Error discovering characteristics for service %@: %@", service.UUID.UUIDString, error];
        [self cleanup];
        return;
    }
    
    for (CBCharacteristic *characteristic in service.characteristics) {
        //[self log:[NSString stringWithFormat:@"Character = %@", characteristic]];
        [peripheral setNotifyValue:YES forCharacteristic:characteristic];
    }
    
    // Send password to board
    NSData *keyData = [self makeKey:_currentPass];
    
    [self trace:@"Sending password: %@", _currentPass];
    
    [_currentPeripheral writeValue:keyData forCharacteristic:[[[_currentPeripheral.services objectAtIndex:0] characteristics] objectAtIndex:1] type:CBCharacteristicWriteWithoutResponse];
}


- (void) syncTime {
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
    [self trace:@"Sync time = %@", data];
    
    [_currentPeripheral writeValue:data forCharacteristic:[[[_currentPeripheral.services objectAtIndex:0] characteristics] objectAtIndex:1] type:CBCharacteristicWriteWithoutResponse];
    
}


- (void) verifyCheck {
    if (!_isVerified) {
        [self trace:@"Incorrect key. Disconnecting from tap $@...", _currentPeripheral.identifier.UUIDString];
        
        [_centralManager cancelPeripheralConnection:_currentPeripheral];
    }
}


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
    
    // Not correct characteristics
    if (![characteristic.UUID.UUIDString isEqualToString:CHARACTERISTIC_UUID_TO_READ])
    {
        return;
    }
    
    /*********** RECEIVE PARAMETER VALUE ***************/
    if (!_isReceivingAudioFile && !_isReceivingLogFile) {
        if([self readParameter:characteristic.value]) { return; }
    }
    
    /*********** RECEIVE AUDIO FILE OR LOG FILE ********************/
    
    // Send back to peripheral number of bytes received.
    NSInteger numBytes = characteristic.value.length;
    NSData *data = [self IntToNSData:numBytes];
    
    [_currentPeripheral writeValue:data forCharacteristic:[[[_currentPeripheral.services objectAtIndex:0] characteristics] objectAtIndex:1] type:CBCharacteristicWriteWithoutResponse];
    
    if (_receiveMode == RECEIVE_AUDIO_FILE) {
        [self handleRecieveAudioFile: characteristic.value
                      withPeripheral: peripheral
                    withChararistics: characteristic];
    } else if (_receiveMode == RECEIVE_LOG_FILE) {
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
    
    // Listen only 2 characterristics
    if (![characteristic.UUID isEqual:[CBUUID UUIDWithString:CHARACTERISTIC_UUID_TO_READ]] &&
        ![characteristic.UUID isEqual:[CBUUID UUIDWithString:CHARACTERISTIC_UUID_TO_WRITE]])
    {
        return;
    }
    
    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:CHARACTERISTIC_UUID_TO_READ]] && !characteristic.isNotifying)
    {
        // Notification has stopped
        [self trace:@"Cancel connection"];
        [_centralManager cancelPeripheralConnection:peripheral];
    }
}


// Disconnect peripheral
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    _currentPeripheral = nil;
    _progress = 0;
    _audioLength = 0;
    _isReceivingAudioFile = false;
    _logLength = 0;
    _isReceivingLogFile = false;
    _receiveMode = RECEIVE_NONE;
    
    _isConnected = NO;
    
    [self trace:@"Disconnected from tap %@", peripheral.identifier.UUIDString];
    
    // Scan for devices again
    if (central.state == CBCentralManagerStatePoweredOn)
    {
        [self clearTapList];
        
        [_centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:SERVICE_UUID]] options:@{ CBCentralManagerScanOptionAllowDuplicatesKey : @NO }];
        [self trace:@"Scanning started"];
    }
}


- (NSUInteger) getFromBytes:(Byte *) byteData {
    int dv = byteData[2]-48;
    int ch =byteData[1]-48;
    int ngh = byteData[0]-48;
    
    NSUInteger value = dv + ch*10 + ngh*100;
    
    return value;
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
        _isVerified = true;
        ret = true;
        
        [self syncTime];
        
        // notify subscribers about connected peripheral
        [[NSNotificationCenter defaultCenter] postNotificationName:kTapNtfn
                                                            object:nil
                                                          userInfo:@{ kTapNtfnType: @kTapNtfnTypeStatus }];
        
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
    }
    
    return ret;
}


- (void)handleRecieveAudioFile: (NSData*)data
                withPeripheral: (CBPeripheral*)peripheral
              withChararistics: (CBCharacteristic*)characteristic {
    if (_audioLength == 0) // First packet
    {
        unsigned int ml;
        
        [characteristic.value getBytes:&ml length:4];
        [self trace:[NSString stringWithFormat:@"Read record metadata: metadata length = %d", ml]];
        
        [characteristic.value getBytes:&_audioLength range:NSMakeRange(4, 4)];
        [self trace:[NSString stringWithFormat:@"Read record metadata: audio length = %d", _audioLength]];
        
        [characteristic.value getBytes:&_audioRecordedTime range:NSMakeRange(8, 4)];
        
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"yyyy-MM-dd_HH:mm:ss"];
        [self trace:[NSString stringWithFormat:@"Read record metadata: record time = %@", [formatter stringFromDate:[self getDateFromInt:_audioRecordedTime]]]];
        
        [self trace:@"Recieveing audio data..."];
        
        _audioBuffer = [[NSMutableData alloc] init];
        _isReceivingAudioFile = true;
        _progress = 0;
    }
    else if (_audioBuffer.length < _audioLength)
    {
        [_audioBuffer appendData:characteristic.value];
        
        float currentProgress = (float)_audioBuffer.length / (float)_audioLength;
        if (fabsf(currentProgress - _progress) >= PROGRESS_LOG_DELTA || _audioBuffer.length == _audioLength) {
            _progress = currentProgress;
            [self trace:@"Received %d%%", (int)(_progress * 100.0f)];
        }
        
        if (_audioBuffer.length == _audioLength)
        {
            [peripheral setNotifyValue:NO forCharacteristic:characteristic];
            
            [self trace:@"Data recieved!"];
            
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            [formatter setDateFormat:@"yyyy-MM-dd_HH-mm-ss"];
            NSString *filePath = [NSString stringWithFormat:@"%@.wav", [formatter stringFromDate:[self getDateFromInt:_audioRecordedTime]]];
            filePath = [DocumentsPath() stringByAppendingPathComponent:filePath];
            
            [_audioBuffer writeToFile:filePath atomically:YES];
            
            [self trace:[NSString stringWithFormat:@"File received = %@.wav", [formatter stringFromDate:[self getDateFromInt:_audioRecordedTime]]]];
            
            // reset
            _audioLength = 0;
            _progress = 0;
            _isReceivingAudioFile = false;
            
            // notify subscribers about new file appearence
            [[NSNotificationCenter defaultCenter] postNotificationName:kTapNtfn
                                                                object:nil
                                                              userInfo:@{ kTapNtfnType: @kTapNtfnTypeFile, kTapNtfnFilePath: filePath }];
        }
    }
}


- (void)handleRecieveLogFile: (NSData*)data
              withPeripheral: (CBPeripheral*)peripheral
            withChararistics: (CBCharacteristic*)characteristic {
    if (_logLength == 0) // First packet
    {
        unsigned int ml;
        
        [data getBytes:&ml length:4];
        [self trace:[NSString stringWithFormat:@"Log metadata: metadata length = %d", ml]];
        
        [data getBytes:&_logLength range:NSMakeRange(4, 4)];
        [self trace:[NSString stringWithFormat:@"Log metadata: log length = %d", _logLength]];
        
        [data getBytes:&_logCreatedTime range:NSMakeRange(8, 4)];
        
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"yyyy-MM-dd_HH:mm:ss"];
        [self trace:[NSString stringWithFormat:@"Log metadata: created time = %@", [formatter stringFromDate:[self getDateFromInt:_logCreatedTime]]]];
        
        [self trace:@"Recieveing log data ..."];
        
        _logBuffer = [[NSMutableData alloc] init];
        _isReceivingLogFile = true;
    }
    else if (_logBuffer.length < _logLength)
    {
        [_logBuffer appendData:data];
        
        if (_logBuffer.length == _logLength)
        {
            [peripheral setNotifyValue:NO forCharacteristic:characteristic];
            
            [self trace:@"Log received!"];
            
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            [formatter setDateFormat:@"yyyy-MM-dd_HH-mm-ss"];
            NSString *filePath = [NSString stringWithFormat:@"Documents/%@_log.txt", [formatter stringFromDate:[self getDateFromInt:_logCreatedTime]]];
            
            NSString *docPath = [NSHomeDirectory() stringByAppendingPathComponent:filePath];
            [_logBuffer writeToFile:docPath atomically:YES];
            
            [self trace:[NSString stringWithFormat:@"File received = %@_log.txt", [formatter stringFromDate:[self getDateFromInt:_logCreatedTime]]]];
            
            // Reset
            _logLength = 0;
            _isReceivingLogFile = false;
        }
    }
}


- (void) sendParameter: (NSData *) data
{
    [_currentPeripheral writeValue:data forCharacteristic:[[[_currentPeripheral.services objectAtIndex:0] characteristics] objectAtIndex:1] type:CBCharacteristicWriteWithoutResponse];
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

/************ END READ PARAMETER ****************/


- (NSString*) getCurrentTapUUID
{
    return _currentPeripheral
        ? _currentPeripheral.identifier.UUIDString
        : nil;
}


- (NSString*)getCurrentTapPassword {
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



@end