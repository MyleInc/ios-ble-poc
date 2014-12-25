#import "CBCentralManagerViewController.h"
#import "ParameterViewController.h"

@interface  CBCentralManagerViewController ()
- (void) scanPeripherals;
- (NSData *)IntToNSData:(NSInteger)data;
- (NSDate*)getDateFromInt:(unsigned int)l;
- (NSString *) formatString:(NSString *)data numberDigit: (NSUInteger)num;
- (NSData *)makeKey:(NSString *)password;
- (Boolean) readParameter:(NSData *)data;

@end

@implementation CBCentralManagerViewController
{
    unsigned int time;
    Boolean isVerified;
    Boolean isDropListSetVisible;
    Boolean isDropListReadVisible;
    Boolean isReceivingAudioFile;
    NSString *initialPassword;
}

@synthesize delegate;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Hide keyboard when user touch outside textfield
    UITapGestureRecognizer *tap =[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(dismissKeyboard)];
    [self.view addGestureRecognizer:tap];
    
    _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    
//    // Load old paramater value
//    [self loadOldParameter];
    
    // Add "Write/Read Parameters" button on the right corner of NavigationBar
    UIBarButtonItem *anotherButton = [[UIBarButtonItem alloc] initWithTitle:@"Parameter" style:UIBarButtonItemStylePlain target:self action:@selector(btDevicePress)];
    self.navigationItem.rightBarButtonItem = anotherButton;
    
    // Set title Navigation ControlBar
    UINavigationController *navCon  = (UINavigationController*) [self.navigationController.viewControllers objectAtIndex:1];
    navCon.navigationItem.title = @"Log";
}

- (void) btDevicePress {
    // Go to DeviceViewcontroller
    [self performSegueWithIdentifier:@"write_read_parameters" sender:self];
}

// Solve topbar hide content
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if([self respondsToSelector:@selector(edgesForExtendedLayout)])
        [self setEdgesForExtendedLayout:UIRectEdgeBottom];
}

// Disconnect
- (void) viewDidDisappear:(BOOL)animated {
//    // Notification has stopped
//    [self log:@"Cancel connection"];
//    [_centralManager cancelPeripheralConnection:_discoveredPeripheral];
}

// set initial password
- (void) setInitialPassword:(NSString *)password {
    self->initialPassword = password;
}

// Scan periphrals with specific service UUID
- (void) scanPeripherals {
    [_centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:SERVICE_UUID]] options:@{ CBCentralManagerScanOptionAllowDuplicatesKey : @YES }];

      //[_centralManager scanForPeripheralsWithServices:nil options:@{ CBCentralManagerScanOptionAllowDuplicatesKey : @YES }];
    
    [self log:@"Scanning started"];
}


- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Make sure your segue name in storyboard is the same as this line
    if ([[segue identifier] isEqualToString:@"write_read_parameters"])
    {
        // Get reference to the destination view controller
        ParameterViewController *vc = [segue destinationViewController];
        
        // Pass any objects to the view controller here, like...
        [vc setPeripheral:self peripheral:self.discoveredPeripheral];
    }
}

// Detect when come back to launcher to disconnect
-(void) viewWillDisappear:(BOOL)animated {
    if ([self.navigationController.viewControllers indexOfObject:self] == NSNotFound) {
        [self.centralManager cancelPeripheralConnection:self.discoveredPeripheral];
    }
    [super viewWillDisappear:animated];
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
    
    NSLog(@"%@", advertisementData);
    
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
    //[self log:@"Connected"];
    
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

- (NSData *)makeKey:(NSString *)password {
    NSData *data;
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
    [self log:[NSString stringWithFormat:@"Send Key: %@, %@", keyData, newStr]];
    
    [_discoveredPeripheral writeValue:keyData forCharacteristic:[[[_discoveredPeripheral.services objectAtIndex:0] characteristics] objectAtIndex:1] type:CBCharacteristicWriteWithoutResponse];
    
//    // Wait 5s
//    [NSTimer scheduledTimerWithTimeInterval:5
//                                     target:self
//                                   selector:@selector(verifyCheck)
//                                   userInfo:nil
//                                    repeats:NO];
    
    
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
    [self log:[NSString stringWithFormat:@"Sync time = %@", data]];
    
    [_discoveredPeripheral writeValue:data forCharacteristic:[[[_discoveredPeripheral.services objectAtIndex:0] characteristics] objectAtIndex:1] type:CBCharacteristicWriteWithoutResponse];
    //    });

}

- (void) verifyCheck {
    if (!isVerified) {
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
        isReceivingAudioFile = true;
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
        [_centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:SERVICE_UUID]] options:@{ CBCentralManagerScanOptionAllowDuplicatesKey : @YES }];
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
    NSLog(@"data =  %@", data);
    Byte *byteData = (Byte*)malloc(3);
    
    NSLog(@"delegate = %@", delegate);
    
    if (!([string rangeOfString:@"5503RECLN"].location == NSNotFound))
    {
        [data getBytes:byteData range:NSMakeRange(@"5503RECLN".length, data.length-@"5503RECLN".length)];
        ret = true;
        str = @"RECLN";
        value = [self getFromBytes:byteData];
        [self.delegate didReceiveRECLN:value];
    }
    else if (!([string rangeOfString:@"5503PAUSELEVEL"].location == NSNotFound))
    {
        [data getBytes:byteData range:NSMakeRange(@"5503PAUSELEVEL".length, data.length-@"5503PAUSELEVEL".length)];
        ret = true;
        str = @"PAUSELEVEL";
        value = [self getFromBytes:byteData];
        [self.delegate didReceivePAUSE_LEVEL:value];
    }
    else if (!([string rangeOfString:@"5503PAUSELEN"].location == NSNotFound))
    {
        [data getBytes:byteData range:NSMakeRange(@"5503PAUSELEN".length, data.length-@"5503PAUSELEN".length)];
        ret = true;
        str = @"PAUSELEN";
        value = [self getFromBytes:byteData];
        [self.delegate didReceivePAUSE_LEN:value];
    }
    else if (!([string rangeOfString:@"5503ACCELERSENS"].location == NSNotFound))
    {
        [data getBytes:byteData range:NSMakeRange(@"5503ACCELERSENS".length, data.length-@"5503ACCELERSENS".length)];
        ret = true;
        str = @"ACCELERSENS";
        value = [self getFromBytes:byteData];
        [self.delegate didReceiveACCELER_SENS:value];
    }
    else if (!([string rangeOfString:@"5503BTLOC"].location == NSNotFound))
    {
        [data getBytes:byteData range:NSMakeRange(@"5503BTLOC".length, data.length-@"5503BTLOC".length)];
        ret = true;
        str = @"BTLOC";
        value = [self getFromBytes:byteData];
        [self.delegate didReceiveBTLOC:value];
    }
    else if (!([string rangeOfString:@"5503MIC"].location == NSNotFound))
    {
        [data getBytes:byteData range:NSMakeRange(@"5503MIC".length, data.length-@"5503MIC".length)];
        ret = true;
        str = @"MIC";
        value = [self getFromBytes:byteData];
        [self.delegate didReceiveMIC:value];
    }
    else if (!([string rangeOfString:@"CONNECTED"].location == NSNotFound))
    {
        self->isVerified = true;
        ret= true;
        [self log:@"Connected"];
        
        [self syncTime];
        return ret;
    }
    
    //[self log:[NSString stringWithFormat:@"%@ = %d", str, value]];
    
    //NSLog([NSString stringWithFormat:@"%@ = %d", str, value]);
    return ret;
}


@end
