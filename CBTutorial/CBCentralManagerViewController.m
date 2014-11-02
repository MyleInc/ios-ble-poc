//
//  CBCentralManagerViewController.m
//  CBTutorial
//
//  Created by Orlando Pereira on 10/8/13.
//  Copyright (c) 2013 Mobiletuts. All rights reserved.
//

#import "CBCentralManagerViewController.h"

NSDate *startTime;
NSDate *stopTime;
NSUInteger numBytesReceive;
NSString *file;

@implementation CBCentralManagerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [_centralManager stopScan];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

// Scan peripheral
- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    // You should test all scenarios
    if (central.state != CBCentralManagerStatePoweredOn) {
        return;
    }
    
    if (central.state == CBCentralManagerStatePoweredOn) {
        // Scan for devices
        [_centralManager scanForPeripheralsWithServices:nil options:@{ CBCentralManagerScanOptionAllowDuplicatesKey : @YES }];
        [self log:@"Scanning started"];
    }
}

//Scan success
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    
    if ([_PeripheralUUID isEqualToString:[peripheral.identifier UUIDString]]) {
        NSLog(@"Same peripheral");
        return;
    }
    
    //[self log:[NSString stringWithFormat:@"UUID = %@\nName = %@\nRSSI = %@ dBm\n", [peripheral.identifier UUIDString], peripheral.name, RSSI]];
    
    if (_discoveredPeripheral != peripheral) {
        // Save a local copy of the peripheral, so CoreBluetooth doesn't get rid of it
        _discoveredPeripheral = peripheral;
    }
    
    _PeripheralUUID = [peripheral.identifier UUIDString];
    
    [_centralManager connectPeripheral:_discoveredPeripheral options:nil];
}

// Scan fail
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    [self log:@"Failed to connect"];
    [self cleanup];
}

// Connect device success callback
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    [_centralManager stopScan];
    //[self log:@"Scanning stopped"];
    [self log:@"Connected"];
    
    [_data setLength:0];
    
    peripheral.delegate = self;
    
    [peripheral discoverServices:nil];
}

// List services
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    if (error) {
        [self cleanup];
        return;
    }
    
    self.lbViewer.text = @"  ";

    // Discover other characteristics
    NSLog(@"Services scanned !");
    for (CBService *s in peripheral.services)
    {
        NSLog(@"Service found : %@", s.UUID);
        //[self log:[NSString stringWithFormat:@"\nService[UUID] = %@\n", s.UUID]];
    }
    
    
    for (CBService *service in peripheral.services) {
        [peripheral discoverCharacteristics:nil forService:service];
    }
}

// List chacracteristics
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    if (error) {
        [self cleanup];
        return;
    }
    
    int count  = 1;
    for (CBCharacteristic *characteristic in service.characteristics) {
        
        NSLog([NSString stringWithFormat:@"%@", characteristic.UUID]);
        
        //[self log:[NSString stringWithFormat:@"\n%d. Characteristics[UUID] = %@\n", count++, characteristic.UUID]];
        
        //if (characteristic.properties == CBCharacteristicPropertyNotify) {
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
        //}
    }
}

// Result of write to peripheral
- (void) peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    NSLog(@"Error = %@", error);
}

// Update value from peripheral
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {

    /** Send back to perip[heral th number of bytes received */
    if (characteristic.value.length != 2) { // 2 is garbage value
        NSInteger numBytes = characteristic.value.length;
        NSData *data = [self IntToNSData:numBytes];
        
        for (CBCharacteristic *characteristic in [[_discoveredPeripheral.services objectAtIndex:0] characteristics]) {
            [_discoveredPeripheral writeValue:data forCharacteristic:characteristic
                                         type:CBCharacteristicWriteWithoutResponse];
        }
    }
    
    /** Convert NSData to NSString */
    NSString *stringFromData = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
    //NSLog(@"%@", stringFromData);
    
    if ([stringFromData rangeOfString:@"SDCard Name" options:NSCaseInsensitiveSearch].location != NSNotFound &&
        stringFromData.length > 0) // start
    {
        [self log:@"Start"];
        
        /** Set bunmer of receive counter */
        numBytesReceive = 0;
        
        /** Start time calc */
        startTime = [NSDate date];
       
        /** Get file name */
        NSArray* foo = [stringFromData componentsSeparatedByString: @" "];
        NSString* fileName = [foo objectAtIndex: 2];
        NSLog(@"name = %@", fileName);
        
        /** Delete file if is already exist */
        NSString *cachesFolder = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
        NSString *path = [cachesFolder stringByAppendingPathComponent:fileName];
        NSError *error;
        if ([[NSFileManager defaultManager] fileExistsAtPath:path])		//Does file exist?
        {
            if (![[NSFileManager defaultManager] removeItemAtPath:path error:&error])	//Delete it
            {
                NSLog(@"Delete file error: %@", error);
            }
        }
        
        /** Create new file */
        cachesFolder = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
        file = [cachesFolder stringByAppendingPathComponent:fileName];
        [[NSData data] writeToFile:file options:NSDataWritingAtomic error:nil];
        
        /** Open file to update */
        self.handle = [NSFileHandle fileHandleForUpdatingAtPath:file];
    }
    else if ([stringFromData rangeOfString:@"SDCard End" options:NSCaseInsensitiveSearch].location != NSNotFound &&
             stringFromData.length > 0) // end
    {
        [self log:@"End"];
        
        /** Close file */
        [self.handle closeFile];
        
        /** Calc time execution */
        stopTime = [NSDate date];
        NSTimeInterval executionTime = [stopTime timeIntervalSinceDate:startTime];
        [self log:[NSString stringWithFormat:@"Time eslapse = %fs", executionTime]];
        
        /** Calc receive speed kbit/s */
        [self log:[NSString stringWithFormat:@"Bytes received = %d Bytes", numBytesReceive]];
        float speed =  numBytesReceive/executionTime;
        [self log:[NSString stringWithFormat:@"Speed = %f Bytes/s", speed]];
        [self log:[NSString stringWithFormat:@"Path: %@", file]];
        
    }
    else if (stringFromData == nil) //data
    {
        NSLog(@"Data = %@", stringFromData);
        
        /** Write data into file */
        [self.handle seekToEndOfFile];
        [self.handle writeData:characteristic.value];
        
        /** Add number received bytes*/
        numBytesReceive += characteristic.value.length;
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
- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    
    if (![characteristic.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_UUID_01]] &&
        ![characteristic.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_UUID_02]]) {
            return;
    }

    if (!characteristic.isNotifying) {
        // Notification has stopped
        [self log:@"Cancel connection"];
        [_centralManager cancelPeripheralConnection:peripheral];
    }
}

// Disconnect peripheral
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    _discoveredPeripheral = nil;
    _PeripheralUUID = @"";
    
     // Scan for devices again
    if (central.state == CBCentralManagerStatePoweredOn) {
       
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
                    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_UUID_01]] ||
                        [characteristic.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_UUID_02]]) {
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
   // [self.tvLog setScrollEnabled:NO];
    [self.tvLog setScrollEnabled:YES];
    //   });
    
}

// Disable rotate screen
- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}


@end
