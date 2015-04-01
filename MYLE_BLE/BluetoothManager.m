#import "BluetoothManager.h"
#import "SERVICES.h"

static BluetoothManager *mBluetoothManager;

@interface  BluetoothManager ()
- (void) scanPeripherals;
- (NSData *)IntToNSData:(NSInteger)data;
- (NSDate*)getDateFromInt:(unsigned int)l;
- (NSString *) formatString:(NSString *)data numberDigit: (NSUInteger)num;
- (NSData *)makeKey:(NSString *)password;
- (Boolean) readParameter:(NSData *)data;

@end

@implementation BluetoothManager
{
    unsigned int time;
    Boolean isVerified;
    Boolean isDropListSetVisible;
    Boolean isDropListReadVisible;
    Boolean isReceivingAudioFile;
    NSString *initialPassword;
    NSUInteger dataLength;
    
    CBCentralManager *centralManager;
    CBPeripheral *discoveredPeripheral;
    CBPeripheralManager *peripheralManager;
    NSMutableData *data;
    NSMutableArray *listDeviceScan;
}

@synthesize parameterDelegate;
@synthesize scanDelegate;
@synthesize logDelegate;

+ (BluetoothManager*) createInstance {
    
    if (nil == mBluetoothManager) {
        mBluetoothManager = [[BluetoothManager alloc] init];
        [mBluetoothManager initManager];
    }

    return mBluetoothManager;
}

- (void) initManager {
    listDeviceScan = [[NSMutableArray alloc] initWithCapacity:100];
    centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
}

+ (void)destroyInstance {
    NSLog(@"destroyInstance");
    [mBluetoothManager disconnect];
     mBluetoothManager = nil;
}

- (void) disconnect {
    NSLog(@"disconnect");
    if (discoveredPeripheral.state == CBPeripheralStateConnecting) {
        [centralManager cancelPeripheralConnection:discoveredPeripheral];
        NSLog(@"disconnect");
        [mBluetoothManager.logDelegate log:@"Disconnected"];
    }
}

- (void)connect : (CBPeripheral*)peripheral {
    discoveredPeripheral = peripheral;
    [centralManager connectPeripheral:discoveredPeripheral options:nil];
    [mBluetoothManager.logDelegate log:@"Connecting"];
}

// set initial password
- (void) setInitialPassword:(NSString *)password {
    self->initialPassword = password;
}

- (void)send:(NSData *)data {
    [discoveredPeripheral writeValue:data forCharacteristic:[[[discoveredPeripheral.services objectAtIndex:0] characteristics] objectAtIndex:1] type:CBCharacteristicWriteWithoutResponse];
}

- (NSString*)getPeripheralUUID {
    return [discoveredPeripheral.identifier UUIDString];
}

// Scan periphrals with specific service UUID
- (void) scanPeripherals {
    [centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:SERVICE_UUID]] options:@{ CBCentralManagerScanOptionAllowDuplicatesKey : @YES }];
    
    //[_centralManager scanForPeripheralsWithServices:nil options:@{ CBCentralManagerScanOptionAllowDuplicatesKey : @YES }];
    
    [mBluetoothManager.logDelegate log:@"start scanning"];
}

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
    
    // Check if have own device
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *uuid = [defaults valueForKey:@"PERIPHERAL_UUID"];
    
    if (nil == uuid) {
        for (ScanDeviceInfo *aDevice in listDeviceScan) {
            if ([[aDevice getPeripheral] isEqual:peripheral])
                return;
        }
        
        ScanDeviceInfo *device = [[ScanDeviceInfo alloc] init:peripheral];
        [listDeviceScan addObject:device];
        [mBluetoothManager.scanDelegate didScanNewDevice:device];
    } else if (nil != uuid && [[peripheral.identifier UUIDString] isEqualToString:uuid]) {
        [self connect:peripheral];
    }
}

// Scan fail
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    [mBluetoothManager.logDelegate log:@"scan failed"];
    [self cleanup];
}

// Connect device success callback
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    [centralManager stopScan];
    NSLog(@"connected");
    
    peripheral.delegate = self;
    
    [peripheral discoverServices:@[[CBUUID UUIDWithString:SERVICE_UUID]]];
}

// List services
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    
    if (error) {
        [self cleanup];
        return;
    }
    
    // Discover other characteristics
    NSLog(@"Services scanned!");
    [mBluetoothManager.logDelegate log:@"Services scanned!"];
    
    // List 2 characteristics
    NSArray * characteristics = [NSArray arrayWithObjects: [CBUUID UUIDWithString:CHARACTERISTIC_UUID_TO_READ], [CBUUID UUIDWithString:CHARACTERISTIC_UUID_TO_WRITE], [CBUUID UUIDWithString:CHARACTERISTIC_UUID_CONFIG], nil];
    
    for (CBService *service in peripheral.services) {
        [peripheral discoverCharacteristics:characteristics forService:service];
    }
}

- (NSData *)makeKey:(NSString *)password {
    NSData *data;
    NSLog(@"pass = %@", password);
    NSData *passData = [password dataUsingEncoding:NSUTF8StringEncoding];
    
    Byte *byteData = (Byte*)malloc(5);
    byteData[0] = [@"5" characterAtIndex:0];
    byteData[1] = [@"5" characterAtIndex:0];
    byteData[2] = [@"0" characterAtIndex:0];
    byteData[3] = [@"1" characterAtIndex:0];
    byteData[4] = password.length & 0xff;
    
    data = [NSData dataWithBytes:byteData length:5];
    //NSLog(@"%@", data);
    
    NSMutableData *concatenatedData = [[NSMutableData alloc] init];
    [concatenatedData appendData:data];
    [concatenatedData appendData:passData];
    
    //NSLog(@"%@", passData);
    //NSLog(@"%@", concatenatedData);
    
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
    NSData *keyData = [self makeKey:self->initialPassword];
    
    // Log
    NSString* newStr = [[NSString alloc] initWithData:keyData encoding:NSUTF8StringEncoding];
    [mBluetoothManager.logDelegate log:[NSString stringWithFormat:@"Send Key: %@, %@", keyData, newStr]];
    
    [peripheral writeValue:keyData forCharacteristic:[[[peripheral.services objectAtIndex:0] characteristics] objectAtIndex:1] type:CBCharacteristicWriteWithoutResponse];
}

- (void) syncTime {
    // Sync time to board
    //    double delayInSeconds = 7.0;
    //    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
    //    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *components = [calendar components:(NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond | NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear) fromDate:[NSDate date]];
    NSInteger hour, minute, second, day, month, year;
    
    hour = [components hour];
    minute = [components minute];
    second = [components second];
    day = [components day];
    month = [components month];
    year = [components year];
    
    NSData *data = [[NSData alloc] init];
    Byte *byteData = (Byte*)malloc(10);
    byteData[0] = [@"5" characterAtIndex:0];
    byteData[1] = [@"5" characterAtIndex:0];
    byteData[2] = [@"0" characterAtIndex:0];
    byteData[3] = [@"0" characterAtIndex:0];
    byteData[4] = second & 0xff;
    byteData[5] = minute & 0xff;
    byteData[6] = hour & 0xff;
    byteData[7] = day & 0xff;
    byteData[8] = month & 0xff;
    byteData[9] = (year - 2000) & 0xff;
    
    data = [NSData dataWithBytes:byteData length:10];
    [mBluetoothManager.logDelegate log:[NSString stringWithFormat:@"Sync time = %@", data]];
    
    [discoveredPeripheral writeValue:data forCharacteristic:[[[discoveredPeripheral.services objectAtIndex:0] characteristics] objectAtIndex:1] type:CBCharacteristicWriteWithoutResponse];
    
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
    NSLog(@"Error = %@", error);
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
    if (!isReceivingAudioFile) {
        if([self readParameter:characteristic.value]) return;
    }
    
    /*********** RECEIVE AUDIO FILE ********************/
    
    // Send back to peripheral number of bytes received.
    NSInteger numBytes = characteristic.value.length;
    NSData *message = [self IntToNSData:numBytes];
    
    [discoveredPeripheral writeValue:message forCharacteristic:[[[discoveredPeripheral.services objectAtIndex:0] characteristics] objectAtIndex:1] type:CBCharacteristicWriteWithoutResponse];
    
    if (dataLength == 0) // First packet
    {
        unsigned int ml;
        
        [characteristic.value getBytes:&ml length:4];
        [mBluetoothManager.logDelegate log:[NSString stringWithFormat:@"Read record metadata: metadata length = %d", ml]];
        
        [characteristic.value getBytes:&dataLength range:NSMakeRange(4, 4)];
        [mBluetoothManager.logDelegate log:[NSString stringWithFormat:@"Read record metadata: audio length = %d", dataLength]];
        
        [characteristic.value getBytes:&time range:NSMakeRange(8, 4)];
        
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"yyyy-MM-dd_HH:mm:ss"];
        [mBluetoothManager.logDelegate log:[NSString stringWithFormat:@"Read record metadata: record time = %@", [formatter stringFromDate:[self getDateFromInt:time]]]];
        
        [mBluetoothManager.logDelegate log:@"Recieveing audio data..."];
        
        data = [[NSMutableData alloc] init];
        isReceivingAudioFile = true;
    }
    else if (data.length < dataLength) // Receive Audio
    {
        [data appendData:characteristic.value];
        //NSLog(@"len = %d", _data.length);
        
        if (data.length == dataLength)
        {
            [peripheral setNotifyValue:NO forCharacteristic:characteristic];
            
            [mBluetoothManager.logDelegate log:@"Data recieved!"];
            
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            [formatter setDateFormat:@"yyyy-MM-dd_HH-mm-ss"];
            NSString *filePath = [NSString stringWithFormat:@"Documents/%@.wav", [formatter stringFromDate:[self getDateFromInt:time]]];
            
            NSString *docPath = [NSHomeDirectory() stringByAppendingPathComponent:filePath];
            [data writeToFile:docPath atomically:YES];
            
            [mBluetoothManager.logDelegate log:[NSString stringWithFormat:@"File received = %@.wav", [formatter stringFromDate:[self getDateFromInt:time]]]];
            
            // Reset
            dataLength = 0;
            isReceivingAudioFile = false;
        }
    }
}

// Convert Integer to NSData
-(NSData *) IntToNSData:(NSInteger)data
{
    Byte *byteData = (Byte*)malloc(1);
    byteData[0] = data & 0xff;
    NSData * result = [NSData dataWithBytes:byteData length:1];
    return (NSData*)result;
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
        [mBluetoothManager.logDelegate log:@"Cancel connection"];
        [centralManager cancelPeripheralConnection:peripheral];
    }
}

// Disconnect peripheral
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    [mBluetoothManager.logDelegate log:@"peripheral disconnectd"];
    discoveredPeripheral = nil;
    
    // Not receive done but disconnect
    dataLength = 0;
    isReceivingAudioFile = false;
    
    // Scan for devices again
    if (central.state == CBCentralManagerStatePoweredOn)
    {
        [centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:SERVICE_UUID]] options:@{ CBCentralManagerScanOptionAllowDuplicatesKey : @YES }];
        [mBluetoothManager.logDelegate log:@"start scanning"];
    }
}

// Clean up
- (void)cleanup {
    
    // See if we are subscribed to a characteristic on the peripheral
    if (discoveredPeripheral.services != nil) {
        for (CBService *service in discoveredPeripheral.services) {
            if (service.characteristics != nil) {
                for (CBCharacteristic *characteristic in service.characteristics) {
                    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:CHARACTERISTIC_UUID_TO_READ]] ||
                        [characteristic.UUID isEqual:[CBUUID UUIDWithString:CHARACTERISTIC_UUID_TO_WRITE]]) {
                        if (characteristic.isNotifying) {
                            [discoveredPeripheral setNotifyValue:NO forCharacteristic:characteristic];
                            return;
                        }
                    }
                }
            }
        }
    }
    
    [centralManager cancelPeripheralConnection:discoveredPeripheral];
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
    NSString *str;
    NSUInteger value = 0;
    
    NSString* string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSLog(@"string = %@", data);
    
    // Audio header
    if (string == nil) return false;
    
    Byte *byteData = (Byte*)malloc(3);
    
    if (!([string rangeOfString:@"5503RECLN"].location == NSNotFound))
    {
        [data getBytes:byteData range:NSMakeRange(@"5503RECLN".length, data.length-@"5503RECLN".length)];
        ret = true;
        str = @"RECLN";
        value = [self getFromBytes:byteData];
        [self.parameterDelegate didReceiveRECLN:value];
    }
    else if (!([string rangeOfString:@"5503PAUSELEVEL"].location == NSNotFound))
    {
        [data getBytes:byteData range:NSMakeRange(@"5503PAUSELEVEL".length, data.length-@"5503PAUSELEVEL".length)];
        ret = true;
        str = @"PAUSELEVEL";
        value = [self getFromBytes:byteData];
        [self.parameterDelegate didReceivePAUSE_LEVEL:value];
    }
    else if (!([string rangeOfString:@"5503PAUSELEN"].location == NSNotFound))
    {
        [data getBytes:byteData range:NSMakeRange(@"5503PAUSELEN".length, data.length-@"5503PAUSELEN".length)];
        ret = true;
        str = @"PAUSELEN";
        value = [self getFromBytes:byteData];
        [self.parameterDelegate didReceivePAUSE_LEN:value];
    }
    else if (!([string rangeOfString:@"5503ACCELERSENS"].location == NSNotFound))
    {
        [data getBytes:byteData range:NSMakeRange(@"5503ACCELERSENS".length, data.length-@"5503ACCELERSENS".length)];
        ret = true;
        str = @"ACCELERSENS";
        value = [self getFromBytes:byteData];
        [self.parameterDelegate didReceiveACCELER_SENS:value];
    }
    else if (!([string rangeOfString:@"5503BTLOC"].location == NSNotFound))
    {
        [data getBytes:byteData range:NSMakeRange(@"5503BTLOC".length, data.length-@"5503BTLOC".length)];
        ret = true;
        str = @"BTLOC";
        value = [self getFromBytes:byteData];
        [self.parameterDelegate didReceiveBTLOC:value];
    }
    else if (!([string rangeOfString:@"5503MIC"].location == NSNotFound))
    {
        [data getBytes:byteData range:NSMakeRange(@"5503MIC".length, data.length-@"5503MIC".length)];
        ret = true;
        str = @"MIC";
        value = [self getFromBytes:byteData];
        [self.parameterDelegate didReceiveMIC:value];
    }
    else if (!([string rangeOfString:@"5503VERSION"].location == NSNotFound))
    {
        Byte *versionData = (Byte*)malloc(20);
        
        [data getBytes:versionData range:NSMakeRange(@"5503VERSION".length + 1, data.length-@"5503VERSION".length - 1)];
        ret = true;
        str = @"VERSION";
        NSLog(@"%d", versionData[0]);
        [self.parameterDelegate didReceiveVERSION:[NSString stringWithUTF8String:versionData]];
    }
    else if (!([string rangeOfString:@"CONNECTED"].location == NSNotFound))
    {
        self->isVerified = true;
        ret= true;
        [mBluetoothManager.logDelegate log:@"Connected"];
        
        [self syncTime];
        return ret;
    }
    
    return ret;
}


@end
