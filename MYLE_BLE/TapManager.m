//
//  TapManager
//  Myle
//
//  Created by Sergey Slobodenyuk on 11.11.14.
//  Copyright (c) 2014 Myle Electronics Corp. All rights reserved.
//

#import "TapManager.h"
#import "Globals.h"
#import "Services.h"



@interface TapManager()
    - (void) notifyListeners:(NSString*)parameterName intValue:(NSUInteger)intValue strValue:(NSString*) strValue;
@end



@implementation TapManager
{
    CBCentralManager *_centralManager;
    CBPeripheral *_discoveredPeripheral;
    NSMutableData *_data;
    unsigned int _dataLength;

    unsigned int _time;
    
    NSString *_password;
    
    Boolean _isVerified;
    Boolean _isDropListSetVisible;
    Boolean _isDropListReadVisible;
    Boolean _isReceivingAudioFile;
    
    NSMutableArray *_listeners;
    
    NSMutableArray *_listDeviceScan;
}



+ (void)setup
{
    [[self class] shared];
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


- (instancetype)init
{
    self = [super init];
    
    _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    _password = [defaults valueForKey:@"TAP-PASSWORD"];
    _password = (_password == nil) ? DEFAULT_TAP_PASSWORD : _password;
    
    _listeners = [[NSMutableArray alloc] init];
    
    _listDeviceScan = [[NSMutableArray alloc] initWithCapacity:100];
    
    return self;
}


// Scan periphrals with specific service UUID
- (void)scanPeripherals {
    switch (_centralManager.state)
    {
        case CBCentralManagerStateUnsupported:
            NSLog(@"MYLE BLE: State: Unsupported");
            break;
            
        case CBCentralManagerStateUnauthorized:
            NSLog(@"MYLE BLE: State: Unauthorized");
            break;
            
        case CBCentralManagerStatePoweredOff:
            NSLog(@"MYLE BLE: State: Powered Off");
            break;
            
        case CBCentralManagerStatePoweredOn:
            NSLog(@"MYLE BLE: State: Powered On");
            [_centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:SERVICE_UUID]] options:@{ CBCentralManagerScanOptionAllowDuplicatesKey : @YES }];
            [self log:@"Scanning started"];
            break;
            
        case CBCentralManagerStateUnknown:
            NSLog(@"MYLE BLE: State: Unknown");
            break;
            
        case CBCentralManagerStateResetting:
            NSLog(@"MYLE BLE: State: Resetting");
            break;
    }
}


// Clean up
- (void)cleanup {
    
    // See if we are subscribed to a characteristic on the peripheral
    if (_discoveredPeripheral.services != nil) {
        for (CBService *service in _discoveredPeripheral.services) {
            if (service.characteristics != nil) {
                for (CBCharacteristic *characteristic in service.characteristics) {
                    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:CHARACTERISTIC_UUID_TO_READ]] ||
                        [characteristic.UUID isEqual:[CBUUID UUIDWithString:CHARACTERISTIC_UUID_TO_WRITE]]) {
                        if (characteristic.isNotifying) {
                            [_discoveredPeripheral setNotifyValue:NO forCharacteristic:characteristic];
                            return;
                        }
                    }
                }
            }
        }
    }
    
    [_centralManager cancelPeripheralConnection:_discoveredPeripheral];
}


// Display log to screen function
- (void)log:(NSString*)s
{
    NSLog(@"MYLE BLE: %@", s);
}


- (void) disconnect {
    if (_discoveredPeripheral != nil && _discoveredPeripheral.state == CBPeripheralStateConnecting) {
        [_centralManager cancelPeripheralConnection:_discoveredPeripheral];
        NSLog(@"disconnect");
    }
}


- (void)connect : (CBPeripheral*)peripheral {
    _discoveredPeripheral = peripheral;
    [_centralManager connectPeripheral:_discoveredPeripheral options:nil];
    NSLog(@"Connecting");
}


#pragma mark - CBCentralManagerDelegate Methods

// Scan peripherals
- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    // You should test all scenarios
    if (central.state != CBCentralManagerStatePoweredOn) {
        return;
    }
    
    if (central.state == CBCentralManagerStatePoweredOn) {
        [self scanPeripherals];
    }
}

//Scan success
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    
    NSLog(@"MYLE BLE: discovered peripheral, advertisement data: %@", advertisementData);
    
    // Check if have own device
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *uuid = [defaults valueForKey:@"PERIPHERAL_UUID"];
    
    if (nil == uuid) {
        for (CBPeripheral *aDevice in _listDeviceScan) {
            if ([aDevice isEqual:peripheral])
                return;
        }
        
        [_listDeviceScan addObject:peripheral];
        
        // notify subscribers abuout new peripheral
        [[NSNotificationCenter defaultCenter] postNotificationName:kDiscoveredPeripheral
                                                            object:nil
                                                          userInfo:@{ kPeripheral: peripheral }];
    } else if (nil != uuid && [[peripheral.identifier UUIDString] isEqualToString:uuid]) {
        [self connect:peripheral];
    }
}


// Scan fail
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    [self log:@"Failed to connect"];
    [self cleanup];
}

// Connect device success callback
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    [_centralManager stopScan];
    [self log:@"Connected"];
    
    peripheral.delegate = self;
    
    [peripheral discoverServices:@[[CBUUID UUIDWithString:SERVICE_UUID]]];
}


#pragma mark - CBPeripheralDelegate Methods

// List services
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    
    if (error) {
        [self cleanup];
        return;
    }
    
    // Discover other characteristics
    NSLog(@"MYLE BLE: Services scanned!");
    
    // List 2 characteristics
    NSArray * characteristics = [NSArray arrayWithObjects: [CBUUID UUIDWithString:CHARACTERISTIC_UUID_TO_READ], [CBUUID UUIDWithString:CHARACTERISTIC_UUID_TO_WRITE], [CBUUID UUIDWithString:CHARACTERISTIC_UUID_CONFIG], nil];
    
    for (CBService *service in peripheral.services) {
        [peripheral discoverCharacteristics:characteristics forService:service];
    }
}

- (NSData *)makeKey:(NSString *)password {
    NSData *data;
    NSData *passData = [_password dataUsingEncoding:NSUTF8StringEncoding];
    
    Byte byteData[10] = { 5, 5, 0, 1, password.length & 0xff };
    
    data = [NSData dataWithBytes:byteData length:5];
    //NSLog(@"MYLE BLE: %@", data);
    
    NSMutableData *concatenatedData = [[NSMutableData alloc] init];
    [concatenatedData appendData:data];
    [concatenatedData appendData:passData];
    
    //NSLog(@"MYLE BLE: %@", passData);
    //NSLog(@"MYLE BLE: %@", concatenatedData);
    
    return concatenatedData;
}

// List chacracteristics
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    if (error) {
        [self cleanup];
        return;
    }
    
    for (CBCharacteristic *characteristic in service.characteristics) {
        //[self log:[NSString stringWithFormat:@"Character = %@", characteristic]];
        [peripheral setNotifyValue:YES forCharacteristic:characteristic];
    }
    
    // Send password to board
    NSData *keyData = [self makeKey:_password];
    
    // Log
    NSString* newStr = [[NSString alloc] initWithData:keyData encoding:NSUTF8StringEncoding];
    [self log:[NSString stringWithFormat:@"Send Key: %@, %@", keyData, newStr]];
    
    [_discoveredPeripheral writeValue:keyData forCharacteristic:[[[_discoveredPeripheral.services objectAtIndex:0] characteristics] objectAtIndex:1] type:CBCharacteristicWriteWithoutResponse];
}

- (void) syncTime {
    // Sync time to board
    //    double delayInSeconds = 7.0;
    //    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
    //    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
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
    Byte byteData[10] = { 5, 5, 0, 0, second & 0xff, minute & 0xff, hour & 0xff, day & 0xff, month & 0xff, (year - 2000) & 0xff };
    
    data = [NSData dataWithBytes:byteData length:10];
    [self log:[NSString stringWithFormat:@"Sync time = %@", data]];
    
    [_discoveredPeripheral writeValue:data forCharacteristic:[[[_discoveredPeripheral.services objectAtIndex:0] characteristics] objectAtIndex:1] type:CBCharacteristicWriteWithoutResponse];
    //    });
    
}

- (void) verifyCheck {
    if (!_isVerified) {
        [self log:@"Incorrect key. Disconnect"];
        
        // Notification has stopped
        [self log:@"Cancel connection"];
        [_centralManager cancelPeripheralConnection:_discoveredPeripheral];
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
    NSLog(@"MYLE BLE: Error = %@", error);
}

// Update value from peripheral
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    
    // Not correct characteristics
    if (![characteristic.UUID.UUIDString isEqualToString:CHARACTERISTIC_UUID_TO_READ])
    {
        return;
    }
    
    /*********** RECEIVE PARAMETER VALUE ***************/
    if (!_isReceivingAudioFile) {
        if([self readParameter:characteristic.value]) return;
    }
    
    /*********** RECEIVE AUDIO FILE ********************/
    
    // Send back to peripheral number of bytes received.
    NSInteger numBytes = characteristic.value.length;
    NSData *data = [self IntToNSData:numBytes];
    
    [_discoveredPeripheral writeValue:data forCharacteristic:[[[_discoveredPeripheral.services objectAtIndex:0] characteristics] objectAtIndex:1] type:CBCharacteristicWriteWithoutResponse];
    
    if (_dataLength == 0) // First packet
    {
        unsigned int ml;
        
        [characteristic.value getBytes:&ml length:4];
        [self log:[NSString stringWithFormat:@"Read record metadata: metadata length = %d", ml]];
        
        [characteristic.value getBytes:&_dataLength range:NSMakeRange(4, 4)];
        [self log:[NSString stringWithFormat:@"Read record metadata: audio length = %d", _dataLength]];
        
        [characteristic.value getBytes:&_time range:NSMakeRange(8, 4)];
        
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"yyyy-MM-dd_HH:mm:ss"];
        [self log:[NSString stringWithFormat:@"Read record metadata: record time = %@", [formatter stringFromDate:[self getDateFromInt:_time]]]];
        
        [self log:@"Recieveing audio data..."];
        
        _data = [[NSMutableData alloc] init];
        _isReceivingAudioFile = true;
    }
    else if (_data.length < _dataLength)
    {
        [_data appendData:characteristic.value];
        //NSLog(@"MYLE BLE: len = %d", _data.length);
        
        if (_data.length == _dataLength)
        {
            [peripheral setNotifyValue:NO forCharacteristic:characteristic];
            
            [self log:@"Data recieved!"];
            
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            [formatter setDateFormat:@"yyyy-MM-dd_HH-mm-ss"];
            NSString *filePath = [NSString stringWithFormat:@"%@.wav", [formatter stringFromDate:[self getDateFromInt:_time]]];
            
            NSString *docPath = [DocumentsPath() stringByAppendingPathComponent:filePath];
            [_data writeToFile:docPath atomically:YES];
            
            [self log:[NSString stringWithFormat:@"File received = %@.wav", [formatter stringFromDate:[self getDateFromInt:_time]]]];
            
            // reset
            _dataLength = 0;
            _isReceivingAudioFile = false;
            
            // notify subscribers about new file appearence
            [[NSNotificationCenter defaultCenter] postNotificationName:kFileReceivedByBluetooth
                                                                object:nil
                                                              userInfo:@{kFilePath: docPath}];
        }
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
    
    // Listen only 2 characterristics
    if (![characteristic.UUID isEqual:[CBUUID UUIDWithString:CHARACTERISTIC_UUID_TO_READ]] &&
        ![characteristic.UUID isEqual:[CBUUID UUIDWithString:CHARACTERISTIC_UUID_TO_WRITE]])
    {
        return;
    }
    
    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:CHARACTERISTIC_UUID_TO_READ]] && !characteristic.isNotifying)
        
    {
        // Notification has stopped
        [self log:@"Cancel connection"];
        [_centralManager cancelPeripheralConnection:peripheral];
    }
}

// Disconnect peripheral
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    _discoveredPeripheral = nil;
    _dataLength = 0;
    _isReceivingAudioFile = false;
    
    // Scan for devices again
    if (central.state == CBCentralManagerStatePoweredOn)
    {
        [_centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:SERVICE_UUID]] options:@{ CBCentralManagerScanOptionAllowDuplicatesKey : @YES }];
        [self log:@"Scanning started"];
    }
}

// Disable rotate screen
- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
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
        [self notifyListeners:@"RECLN" intValue:[self getFromBytes:byteData] strValue:nil];
    }
    else if (!([string rangeOfString:@"5503PAUSELEVEL"].location == NSNotFound))
    {
        [data getBytes:byteData range:NSMakeRange(@"5503PAUSELEVEL".length, data.length-@"5503PAUSELEVEL".length)];
        ret = true;
        [self notifyListeners:@"PAUSELEVEL" intValue:[self getFromBytes:byteData] strValue:nil];
    }
    else if (!([string rangeOfString:@"5503PAUSELEN"].location == NSNotFound))
    {
        [data getBytes:byteData range:NSMakeRange(@"5503PAUSELEN".length, data.length-@"5503PAUSELEN".length)];
        ret = true;
        [self notifyListeners:@"PAUSELEN" intValue:[self getFromBytes:byteData] strValue:nil];
    }
    else if (!([string rangeOfString:@"5503ACCELERSENS"].location == NSNotFound))
    {
        [data getBytes:byteData range:NSMakeRange(@"5503ACCELERSENS".length, data.length-@"5503ACCELERSENS".length)];
        ret = true;
        [self notifyListeners:@"ACCELERSENS" intValue:[self getFromBytes:byteData] strValue:nil];
    }
    else if (!([string rangeOfString:@"5503BTLOC"].location == NSNotFound))
    {
        [data getBytes:byteData range:NSMakeRange(@"5503BTLOC".length, data.length-@"5503BTLOC".length)];
        ret = true;
        [self notifyListeners:@"BTLOC" intValue:[self getFromBytes:byteData] strValue:nil];
    }
    else if (!([string rangeOfString:@"5503MIC"].location == NSNotFound))
    {
        [data getBytes:byteData range:NSMakeRange(@"5503MIC".length, data.length-@"5503MIC".length)];
        ret = true;
        [self notifyListeners:@"MIC" intValue:[self getFromBytes:byteData] strValue:nil];
    }
    else if (!([string rangeOfString:@"5503VERSION"].location == NSNotFound))
    {
        Byte versionData[20] = { 0 };
        
        [data getBytes:versionData range:NSMakeRange(@"5503VERSION".length + 1, data.length - @"5503VERSION".length - 1)];
        ret = true;
        NSString *version = [NSString stringWithUTF8String:(const char *)versionData];
        NSLog(@"MYLE BLE: Device version received: %@", version);
        [self notifyListeners:@"VERSION" intValue:0 strValue:version];
    }
    else if (!([string rangeOfString:@"CONNECTED"].location == NSNotFound))
    {
        _isVerified = true;
        ret= true;
        [self log:@"Connected"];
        
        [self syncTime];
        return ret;
    }
    
    //[self log:[NSString stringWithFormat:@"%@ = %d", str, value]];
    
    NSLog(@"MYLE BLE: ret = %d", ret);
    return ret;
}


- (void) sendParameter: (NSData *) data
{
    [_discoveredPeripheral writeValue:data forCharacteristic:[[[_discoveredPeripheral.services objectAtIndex:0] characteristics] objectAtIndex:1] type:CBCharacteristicWriteWithoutResponse];
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
    _password = value;

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setValue:_password forKey:@"TAP-PASSWORD"];
    [defaults synchronize];
    
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
    return _discoveredPeripheral
        ? [NSString stringWithFormat:@"%@", [[[_discoveredPeripheral services] objectAtIndex:0] UUID]]
        : nil;
}


- (NSString*)getCurrentPassword {
    return _password;
}


- (void) addParameterReadListener:(Listener)listener
{
    for (int i = 0; i < _listeners.count; i ++) {
        if ((Listener)_listeners[i] == listener) {
            // listener already added
            return;
        }
    }
    [_listeners addObject:listener];
}


- (void) notifyListeners:(NSString*)parameterName intValue:(NSUInteger)intValue strValue:(NSString*) strValue;
{
    for (Listener listener in _listeners) {
        if (listener) {
            listener(parameterName, intValue, strValue);
        }
    }
}



@end