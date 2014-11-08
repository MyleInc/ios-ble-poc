#import "CBCentralManagerViewController.h"

@interface  CBCentralManagerViewController ()
- (void) scanPeripherals;
- (NSData *) IntToNSData:(NSInteger)data;
- (NSDate*)getDateFromInt:(unsigned int)l;

@end

@implementation CBCentralManagerViewController
{
    unsigned int time;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
}

// Scan periphrals with specific service UUID
- (void) scanPeripherals {
    [_centralManager scanForPeripheralsWithServices:nil options:@{ CBCentralManagerScanOptionAllowDuplicatesKey : @YES }];
    
    [self log:@"Scanning started"];
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
    
    //[self log:[NSString stringWithFormat:@"DATA=\"%@\"", advertisementData]];
    
    if (_discoveredPeripheral != peripheral) {
        NSLog(@"Scan success");

        // Save a local copy of the peripheral, so CoreBluetooth doesn't get rid of it
        _discoveredPeripheral = peripheral;
    
        _PeripheralUUID = [peripheral.identifier UUIDString];
    
        [_centralManager connectPeripheral:_discoveredPeripheral options:nil];
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

// List services
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    
    if (error) {
        [self cleanup];
        return;
    }
    
    // Discover other characteristics
    NSLog(@"Services scanned !");
    for (CBService *s in peripheral.services)
    {
        NSLog(@"Service found : \"%@\"", s.UUID);
        //[self log:[NSString stringWithFormat:@"\nService[UUID] = %@\n", s.UUID]];
    }
    
    // List 2 characteristics
    NSArray * characteristics = [NSArray arrayWithObjects: [CBUUID UUIDWithString:CHARACTERISTIC_UUID_TO_READ], [CBUUID UUIDWithString:CHARACTERISTIC_UUID_TO_WRITE], [CBUUID UUIDWithString:CHARACTERISTIC_UUID_CONFIG], nil];
    
    for (CBService *service in peripheral.services) {
        [peripheral discoverCharacteristics:characteristics forService:service];
    }
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
    Byte *byteData = (Byte*)malloc(6);
    byteData[0] = second & 0xff;
    byteData[1] = minute & 0xff;
    byteData[2] = hour & 0xff;
    byteData[3] = day & 0xff;
    byteData[4] = month & 0xff;
    byteData[5] = (year - 2000) & 0xff;
    
    data = [NSData dataWithBytes:byteData length:6];
    [self log:[NSString stringWithFormat:@"Send = %@", data]];
    
    [_discoveredPeripheral writeValue:data forCharacteristic:[[[_discoveredPeripheral.services objectAtIndex:0] characteristics] objectAtIndex:1] type:CBCharacteristicWriteWithoutResponse];
    //    });
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
    
    // Send back to peripheral number of bytes received.
    NSInteger numBytes = characteristic.value.length;
    NSData *data = [self IntToNSData:numBytes];
    
    [_discoveredPeripheral writeValue:data forCharacteristic:[[[_discoveredPeripheral.services objectAtIndex:0] characteristics] objectAtIndex:1] type:CBCharacteristicWriteWithoutResponse];
    
    if (self.dataLength == 0) // First packet
    {
        unsigned int ml;
        
        [characteristic.value getBytes:&ml length:4];
        [self log:[NSString stringWithFormat:@"Read record metadata: metadata length = %d", ml]];
        
        [characteristic.value getBytes:&_dataLength range:NSMakeRange(4, 4)];
        [self log:[NSString stringWithFormat:@"Read record metadata: audio length = %d", _dataLength]];
        
        [characteristic.value getBytes:&time range:NSMakeRange(8, 4)];
        
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"yyyy-MM-dd_HH:mm:ss"];
        [self log:[NSString stringWithFormat:@"Read record metadata: record time = %@", [formatter stringFromDate:[self getDateFromInt:time]]]];
        
        [self log:@"Recieveing audio data..."];
        
        _data = [[NSMutableData alloc] init];
    }
    else if (_data.length < _dataLength)
    {
        [_data appendData:characteristic.value];
        NSLog(@"len = %d", _data.length);
        
        if (_data.length == _dataLength)
        {
            [peripheral setNotifyValue:NO forCharacteristic:characteristic];
            
            [self log:@"Data recieved!"];
            
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            [formatter setDateFormat:@"yyyy-MM-dd_HH-mm-ss"];
            NSString *filePath = [NSString stringWithFormat:@"Documents/%@.wav", [formatter stringFromDate:[self getDateFromInt:time]]];
            
            NSString *docPath = [NSHomeDirectory() stringByAppendingPathComponent:filePath];
            [_data writeToFile:docPath atomically:YES];
            
            [self log:[NSString stringWithFormat:@"File received = %@.wav", [formatter stringFromDate:[self getDateFromInt:time]]]];
            
            // reset
            _dataLength = 0;
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
        [self log:@"Cancel connection"];
        [_centralManager cancelPeripheralConnection:peripheral];
    }
}

// Disconnect peripheral
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    _discoveredPeripheral = nil;
    _PeripheralUUID = @"";
    
    // Scan for devices again
    if (central.state == CBCentralManagerStatePoweredOn)
    {
        [_centralManager scanForPeripheralsWithServices:nil options:@{ CBCentralManagerScanOptionAllowDuplicatesKey : @YES }];
        [self log:@"Scanning started"];
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
-(void) log:(NSString*)s
{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"HH:mm:ss.SSS"];
    
    self.tvLog.text = [NSString stringWithFormat:@"%@\r\n%@: %@", self.tvLog.text, [formatter stringFromDate:[NSDate date]], s];
    
    [self.tvLog scrollRangeToVisible:NSMakeRange([self.tvLog.text length], 0)];
    [self.tvLog setScrollEnabled:YES];
    
}

// Disable rotate screen
- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}


@end
