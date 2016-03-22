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


typedef struct {
    UInt16  fileIndex;
    Byte command;
} AudioFileDisposition;


typedef struct {
    Byte  version;
    Byte  fileExists;
    Byte  timeValid;
    Byte  codeId;
    Byte  second;
    Byte  minute;
    Byte  hour;
    Byte  day;
    Byte  month;
    Byte  year;
    UInt32  fileSize;
    UInt16  packetSize;
    UInt16 fileIndex;
} AudioFileStored;



@implementation TapManager
{
    CBCentralManager *_centralManager;
    CBPeripheral *_currentPeripheral;
    CBPeripheral *_peripheralTempRef;
    
    // Settings
    CBCharacteristic* _SETTING_AUDIO_LENGTH;
    CBCharacteristic* _SETTING_MIC_LEVEL;
    CBCharacteristic* _SETTING_SILENCE_LEVEL;
    CBCharacteristic* _SETTING_SILENCE_LENGTH;
    CBCharacteristic* _SETTING_ACCELEROMETER_SENSITIVITY;
    CBCharacteristic* _SETTING_PASSWORD;
    
    // Commands
    CBCharacteristic* _COMMAND_AUDIO_FILE_DISPOSITION;
    CBCharacteristic* _COMMAND_AUDIO_FILE_RECEIVED;
    CBCharacteristic* _COMMAND_BLUETOOTH_LOCATOR;
    CBCharacteristic* _COMMAND_FACTORY_RESET;
    CBCharacteristic* _COMMAND_PASSWORD;
    CBCharacteristic* _COMMAND_UPDATE_TIME;
    
    // Status
    CBCharacteristic* _STATUS_AUDIO_FILE_PACKET;
    CBCharacteristic* _STATUS_AUDIO_FILE_SENT;
    CBCharacteristic* _STATUS_AUDIO_FILE_STORED;
    CBCharacteristic* _STATUS_PASSWORD_VALIDITY;
    
    // Battery
    CBCharacteristic* _batteryLevelChrt;
    
    // DevInfo
    CBCharacteristic* _devInfoHardwareRevChrt;
    CBCharacteristic* _devInfoFirmwareRevChrt;
    
    NSString *_currentUUID;
    NSString *_currentPass;
    NSString *_currentMAC;
    
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
    
    NSMutableDictionary *_uuidMacMap;
    
    NSArray *_myleChrts;
    
    UInt32 _currentFileIndex;
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
    
    _myleChrts = @[
                   MYLE_CHAR_SETTING_AUDIO_LENGTH,
                   MYLE_CHAR_SETTING_MIC_LEVEL,
                   MYLE_CHAR_SETTING_SILENCE_LEVEL,
                   MYLE_CHAR_SETTING_SILENCE_LENGTH,
                   MYLE_CHAR_SETTING_ACCELEROMETER_SENSITIVITY,
                   MYLE_CHAR_SETTING_PASSWORD,
                   
                   MYLE_CHAR_COMMAND_AUDIO_FILE_DISPOSITION,
                   MYLE_CHAR_COMMAND_AUDIO_FILE_RECEIVED,
                   MYLE_CHAR_COMMAND_BLUETOOTH_LOCATOR,
                   MYLE_CHAR_COMMAND_FACTORY_RESET,
                   MYLE_CHAR_COMMAND_PASSWORD,
                   MYLE_CHAR_COMMAND_UPDATE_TIME,
                   
                   MYLE_CHAR_STATUS_AUDIO_FILE_PACKET,
                   MYLE_CHAR_STATUS_AUDIO_FILE_SENT,
                   MYLE_CHAR_STATUS_AUDIO_FILE_STORED,
                   MYLE_CHAR_STATUS_PASSWORD_VALIDITY
    ];
    
    dispatch_queue_t centralQueue = dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0);
    
    _centralManager = [[CBCentralManager alloc] initWithDelegate:self
                                                           queue:centralQueue
                                                         options:@{ CBCentralManagerOptionRestoreIdentifierKey: @"myleCentralManager" }];
    
    _currentPass = DEFAULT_TAP_PASSWORD;
    
    _readParameterListeners = [[NSMutableArray alloc] init];
    _traceListeners = [[NSMutableArray alloc] init];
    
    _availableTaps = [[NSMutableArray alloc] initWithCapacity:100];
    
    _uuidMacMap = [[NSMutableDictionary alloc] init];
    
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


// Sends a command to tap to make some noise
- (void)locate {
    [self trace:@"Sending 'Bluetooth Locator' command"];
    Byte bytes[1] = { 0x01 };
    [_currentPeripheral writeValue:[NSData dataWithBytes:bytes length:1] forCharacteristic:_COMMAND_BLUETOOTH_LOCATOR type:CBCharacteristicWriteWithResponse];
}


// Resets tap to factory defaults
- (void)resetToFactoryDefaults {
    [self trace:@"Sending 'Factory Reset' command"];
    Byte bytes[1] = { 0x01 };
    [_currentPeripheral writeValue:[NSData dataWithBytes:bytes length:1] forCharacteristic:_COMMAND_FACTORY_RESET type:CBCharacteristicWriteWithResponse];
}



// Start scan
- (void)startScan {
    if (_isScanning) { return; }
    
    _isScanning = YES;
    
    [self clearTapList];
    
    NSArray *servicesTap = [NSArray arrayWithObjects: [CBUUID UUIDWithString:MYLE_SERVICE] , nil];
    [_centralManager scanForPeripheralsWithServices:servicesTap options:@{ CBCentralManagerScanOptionAllowDuplicatesKey : @NO }];
    [self trace:@"Scan started"];
}

// Stop scan
- (void)stopScan {
    if (!_isScanning) { return; }
    
    _isScanning = NO;
    
    [_centralManager stopScan];
    [self trace:@"Scan stopped"];
}


-(CBService*)getService:(NSString*) serviceUUID forPeripheral:(CBPeripheral*)p {
    for (CBService *s in p.services) {
        if ([s.UUID.UUIDString isEqual:serviceUUID]) {
            return s;
        }
    }
    return nil;
}

-(CBCharacteristic*)getCharacteristic:(NSString*) characteristicUUID forService:(CBService*)s {
    for (CBCharacteristic *c in s.characteristics) {
        if ([c.UUID.UUIDString isEqual:characteristicUUID]) {
            return c;
        }
    }
    return nil;
}


// Ensures services and characteristics are disconvered for the peripheral
-(void)ensurePeripheralIsInitialized:(CBPeripheral*) peripheral {
    if (!peripheral) { return; }
    
    [self trace:@"Looks like we are in state restoration state, ensure peripheral is initialized..."];
    
    if (peripheral.state == CBPeripheralStateConnected) {
        // have we disconvered our services?
        CBService *service = [self getService:MYLE_SERVICE forPeripheral:peripheral];
        CBService *batteryService = [self getService:BATTERY_SERVICE_UUID forPeripheral:peripheral];
        CBService *devInfoService = [self getService:DEVINFO_SERVICE_UUID forPeripheral:peripheral];
        if (!service || !batteryService || !devInfoService) {
            // we haven't yet!
            NSArray *services = @[[CBUUID UUIDWithString:MYLE_SERVICE], [CBUUID UUIDWithString:BATTERY_SERVICE_UUID], [CBUUID UUIDWithString:DEVINFO_SERVICE_UUID]];
            [peripheral discoverServices:services];
            return;
        }
        
        // have we discovered MYLE characteristics?
        _SETTING_AUDIO_LENGTH = [self getCharacteristic:MYLE_CHAR_SETTING_AUDIO_LENGTH forService:service];
        _SETTING_MIC_LEVEL = [self getCharacteristic:MYLE_CHAR_SETTING_MIC_LEVEL forService:service];
        _SETTING_SILENCE_LEVEL = [self getCharacteristic:MYLE_CHAR_SETTING_SILENCE_LEVEL forService:service];
        _SETTING_SILENCE_LENGTH = [self getCharacteristic:MYLE_CHAR_SETTING_SILENCE_LENGTH forService:service];
        _SETTING_ACCELEROMETER_SENSITIVITY = [self getCharacteristic:MYLE_CHAR_SETTING_ACCELEROMETER_SENSITIVITY forService:service];
        _SETTING_PASSWORD = [self getCharacteristic:MYLE_CHAR_SETTING_PASSWORD forService:service];
        
        _COMMAND_AUDIO_FILE_DISPOSITION = [self getCharacteristic:MYLE_CHAR_COMMAND_AUDIO_FILE_DISPOSITION forService:service];
        _COMMAND_AUDIO_FILE_RECEIVED = [self getCharacteristic:MYLE_CHAR_COMMAND_AUDIO_FILE_RECEIVED forService:service];
        _COMMAND_BLUETOOTH_LOCATOR = [self getCharacteristic:MYLE_CHAR_COMMAND_BLUETOOTH_LOCATOR forService:service];
        _COMMAND_FACTORY_RESET = [self getCharacteristic:MYLE_CHAR_COMMAND_FACTORY_RESET forService:service];
        _COMMAND_PASSWORD = [self getCharacteristic:MYLE_CHAR_COMMAND_PASSWORD forService:service];
        _COMMAND_UPDATE_TIME = [self getCharacteristic:MYLE_CHAR_COMMAND_UPDATE_TIME forService:service];
        
        _STATUS_AUDIO_FILE_PACKET = [self getCharacteristic:MYLE_CHAR_STATUS_AUDIO_FILE_PACKET forService:service];
        _STATUS_AUDIO_FILE_SENT = [self getCharacteristic:MYLE_CHAR_STATUS_AUDIO_FILE_SENT forService:service];
        _STATUS_AUDIO_FILE_STORED = [self getCharacteristic:MYLE_CHAR_STATUS_AUDIO_FILE_STORED forService:service];
        _STATUS_PASSWORD_VALIDITY = [self getCharacteristic:MYLE_CHAR_STATUS_PASSWORD_VALIDITY forService:service];
        
        if (!_SETTING_AUDIO_LENGTH ||
            !_SETTING_MIC_LEVEL ||
            !_SETTING_SILENCE_LEVEL ||
            !_SETTING_SILENCE_LENGTH ||
            !_SETTING_ACCELEROMETER_SENSITIVITY ||
            !_SETTING_PASSWORD ||
            !_COMMAND_AUDIO_FILE_DISPOSITION ||
            !_COMMAND_AUDIO_FILE_RECEIVED ||
            !_COMMAND_BLUETOOTH_LOCATOR ||
            !_COMMAND_FACTORY_RESET ||
            !_COMMAND_PASSWORD ||
            !_COMMAND_UPDATE_TIME ||
            !_STATUS_AUDIO_FILE_PACKET ||
            !_STATUS_AUDIO_FILE_SENT ||
            !_STATUS_AUDIO_FILE_STORED ||
            !_STATUS_PASSWORD_VALIDITY) {
            [peripheral discoverCharacteristics:_myleChrts forService:service];
            return;
        }
        
        // have we discovered battery characteristics?
        _batteryLevelChrt = [self getCharacteristic:BATTERY_LEVEL_UUID forService:batteryService];
        if (!_batteryLevelChrt) {
            [peripheral discoverCharacteristics:@[BATTERY_LEVEL_UUID] forService:batteryService];
            return;
        }
        
        // have we discovered dev info characteristics
        _devInfoHardwareRevChrt = [self getCharacteristic:DEVINFO_HARDWARE_REV_UUID forService:devInfoService];
        _devInfoFirmwareRevChrt = [self getCharacteristic:DEVINFO_FIRMWARE_REV_UUID forService:devInfoService];
        if (!_devInfoHardwareRevChrt || !_devInfoFirmwareRevChrt) {
            [peripheral discoverCharacteristics:@[DEVINFO_HARDWARE_REV_UUID, DEVINFO_FIRMWARE_REV_UUID] forService:devInfoService];
            return;
        }
        
        // are we subscribed?
        if (_STATUS_AUDIO_FILE_PACKET && !_STATUS_AUDIO_FILE_PACKET.isNotifying) {
            [peripheral setNotifyValue:YES forCharacteristic:_STATUS_AUDIO_FILE_PACKET];
        }
        if (_STATUS_AUDIO_FILE_STORED && !_STATUS_AUDIO_FILE_STORED.isNotifying) {
            [peripheral setNotifyValue:YES forCharacteristic:_STATUS_AUDIO_FILE_STORED];
        }
        if (_STATUS_AUDIO_FILE_SENT && !_STATUS_AUDIO_FILE_SENT.isNotifying) {
            [peripheral setNotifyValue:YES forCharacteristic:_STATUS_AUDIO_FILE_SENT];
        }
        if (_STATUS_PASSWORD_VALIDITY && !_STATUS_PASSWORD_VALIDITY.isNotifying) {
            [peripheral setNotifyValue:YES forCharacteristic:_STATUS_PASSWORD_VALIDITY];
        }
        
        if (!_batteryLevelChrt.isNotifying) {
            [peripheral setNotifyValue:YES forCharacteristic:_batteryLevelChrt];
        }
    }
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
            if (_currentPeripheral) {
                [self centralManager:central didDisconnectPeripheral:_currentPeripheral error:nil];
            }
            break;
            
        case CBCentralManagerStatePoweredOn:
            [self trace:@"BLE state: powered on"];
            if (_currentPeripheral) {
                [self ensurePeripheralIsInitialized:_currentPeripheral];
            } else {
                [self startScan];
            }
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
    // Acording to http://stackoverflow.com/questions/25390484/obtaining-bluetooth-le-scan-response-data-with-ios#comment46402518_25392156
    // didDiscoverPeripheral is called twice: one time with advertisment data and the seconds time with scan response
    // NOTE: in background mode the second call may not occur, so we will have to cache it in order to get MAC address for auto-reconnection
    
    [self trace:@"Discovered peripheral %@ with advertisement data: %@", peripheral, advertisementData];
    
    [_uuidMacMap setObject:[advertisementData objectForKey:@"kCBAdvDataManufacturerData"] forKey:peripheral.identifier.UUIDString];
    
    // if devices is not in our list - add it and notify subscribers
    if ([_availableTaps containsObject:peripheral]) { return; }
    
    [_availableTaps addObject:peripheral];

    // notify subscribers about new peripheral
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
        [_centralManager connectPeripheral:peripheral options:nil];
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
    
    [self trace:@"Connected to tap %@", peripheral.identifier.UUIDString];
    
    _currentPeripheral = peripheral;
    NSData *macData = (NSData*)[_uuidMacMap objectForKey:peripheral.identifier.UUIDString];
    if (macData) {
        Byte *mac = (Byte*)macData.bytes;
        _currentMAC = [NSString stringWithFormat:@"%02x:%02x:%02x:%02x:%02x:%02x", mac[5], mac[4], mac[3], mac[2], mac[1], mac[0]];
    } else {
        _currentMAC = @"[No MAC received]";
    }
    
    peripheral.delegate = self;
    
    NSArray * servicesTap = [NSArray arrayWithObjects: [CBUUID UUIDWithString:MYLE_SERVICE], [CBUUID UUIDWithString:DEVINFO_SERVICE_UUID], [CBUUID UUIDWithString:BATTERY_SERVICE_UUID], nil];
    
    [self trace:@"Discovering services...."];
    [peripheral discoverServices:servicesTap];
}


// Disconnect peripheral
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    [self trace:@"Disconnected from tap %@ (error: %@)", peripheral.identifier.UUIDString, error];
    
    if (error) {
        if (error.code == 7 && _isAuthenticating) {
            // code 7 means "The specified device has disconnected from us."
            // so tap forces disconnection
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
            [self trace:@"Will connect to tap once it's available %@", peripheral.identifier.UUIDString];
            [_centralManager connectPeripheral:peripheral options:nil];
            
            // keep reference to given peripheral, so CoreBluetooth would think we are still interested in it
            // Otherwise we would see the following error:
            // API MISUSE: Cancelling connection for unused peripheral <CBPeripheral: 0x15577240, identifier = 5F7B3540-AEA0-01FD-6CF2-C2570F18E0A9, name = MYLE, state = connecting>, Did you forget to keep a reference to it?
            // We could use _currentPeripheral for that, but it's better to separate them,
            // because _currentPeripheral reflects currently connected peripheral,
            // while _peripheralTempRef - just to make CoreBluetooth happy

            _peripheralTempRef = peripheral;
        }
    }
    
    _currentMAC = nil;
    _currentPeripheral = nil;
    _progress = 0;
    _audioLength = 0;
    _isReceivingAudioFile = false;
    _logLength = 0;
    _isReceivingLogFile = false;
    _receiveMode = RECEIVE_NONE;
    _isConnected = NO;
    _isAuthenticating = NO;
    
    _SETTING_AUDIO_LENGTH = nil,
    _SETTING_MIC_LEVEL = nil,
    _SETTING_SILENCE_LEVEL = nil,
    _SETTING_SILENCE_LENGTH = nil,
    _SETTING_ACCELEROMETER_SENSITIVITY = nil;
    _SETTING_PASSWORD = nil;
    
    _COMMAND_AUDIO_FILE_DISPOSITION = nil;
    _COMMAND_AUDIO_FILE_RECEIVED = nil;
    _COMMAND_BLUETOOTH_LOCATOR = nil;
    _COMMAND_FACTORY_RESET = nil;
    _COMMAND_PASSWORD = nil;
    _COMMAND_UPDATE_TIME = nil;
    
    _STATUS_AUDIO_FILE_PACKET = nil;
    _STATUS_AUDIO_FILE_SENT = nil;
    _STATUS_AUDIO_FILE_STORED = nil;
    _STATUS_PASSWORD_VALIDITY = nil;
    
    _batteryLevelChrt = nil;
    _devInfoHardwareRevChrt = nil;
    _devInfoFirmwareRevChrt = nil;
}


- (void)centralManager:(CBCentralManager *)central willRestoreState:(NSDictionary<NSString *, id> *)dict {
    [self trace:@"Restoring BT state with data: %@", dict];
    
    NSArray *peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey];
    if (peripherals.count) {
        _currentPeripheral = [peripherals firstObject];
        _currentPeripheral.delegate = self;
    }
}


#pragma mark - CBPeripheralDelegate Methods

// List services
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    if (error) {
        [self trace:@"Error discovering services %@", error];
        [self cleanup];
        return;
    }
    [self trace:@"Discovering characteristics for services %@...", peripheral.services];
    
    
    NSArray * characteristics = [NSArray arrayWithObjects:
                                 [CBUUID UUIDWithString:MYLE_CHAR_SETTING_AUDIO_LENGTH],
                                 [CBUUID UUIDWithString:MYLE_CHAR_SETTING_MIC_LEVEL],
                                 [CBUUID UUIDWithString:MYLE_CHAR_SETTING_SILENCE_LEVEL],
                                 [CBUUID UUIDWithString:MYLE_CHAR_SETTING_SILENCE_LENGTH],
                                 [CBUUID UUIDWithString:MYLE_CHAR_SETTING_ACCELEROMETER_SENSITIVITY],
                                 [CBUUID UUIDWithString:MYLE_CHAR_SETTING_PASSWORD],
                                 
                                 [CBUUID UUIDWithString:MYLE_CHAR_COMMAND_AUDIO_FILE_DISPOSITION],
                                 [CBUUID UUIDWithString:MYLE_CHAR_COMMAND_AUDIO_FILE_RECEIVED],
                                 [CBUUID UUIDWithString:MYLE_CHAR_COMMAND_BLUETOOTH_LOCATOR],
                                 [CBUUID UUIDWithString:MYLE_CHAR_COMMAND_FACTORY_RESET],
                                 [CBUUID UUIDWithString:MYLE_CHAR_COMMAND_PASSWORD],
                                 [CBUUID UUIDWithString:MYLE_CHAR_COMMAND_UPDATE_TIME],
                                 
                                 [CBUUID UUIDWithString:MYLE_CHAR_STATUS_AUDIO_FILE_PACKET],
                                 [CBUUID UUIDWithString:MYLE_CHAR_STATUS_AUDIO_FILE_SENT],
                                 [CBUUID UUIDWithString:MYLE_CHAR_STATUS_AUDIO_FILE_STORED],
                                 [CBUUID UUIDWithString:MYLE_CHAR_STATUS_PASSWORD_VALIDITY],
                                 
                                 [CBUUID UUIDWithString:DEVINFO_FIRMWARE_REV_UUID],
                                 [CBUUID UUIDWithString:DEVINFO_HARDWARE_REV_UUID],
                                 
                                 [CBUUID UUIDWithString:BATTERY_LEVEL_UUID],
                                 
                                 nil];
    for (CBService *service in peripheral.services) {
        [peripheral discoverCharacteristics:characteristics forService:service];
    }
}


- (void) initCharacterisitcsForService:(CBService *)service {
    if ([[service UUID] isEqual:[CBUUID UUIDWithString:BATTERY_SERVICE_UUID]]) {
        _batteryLevelChrt = [self getCharacteristic:BATTERY_LEVEL_UUID forService:service];
        [service.peripheral setNotifyValue:YES forCharacteristic:_batteryLevelChrt];
    } else if ([[service UUID] isEqual:[CBUUID UUIDWithString:MYLE_SERVICE]]) {
        _SETTING_AUDIO_LENGTH = [self getCharacteristic:MYLE_CHAR_SETTING_AUDIO_LENGTH forService:service];
        _SETTING_MIC_LEVEL = [self getCharacteristic:MYLE_CHAR_SETTING_MIC_LEVEL forService:service];
        _SETTING_SILENCE_LEVEL = [self getCharacteristic:MYLE_CHAR_SETTING_SILENCE_LEVEL forService:service];
        _SETTING_SILENCE_LENGTH = [self getCharacteristic:MYLE_CHAR_SETTING_SILENCE_LENGTH forService:service];
        _SETTING_ACCELEROMETER_SENSITIVITY = [self getCharacteristic:MYLE_CHAR_SETTING_ACCELEROMETER_SENSITIVITY forService:service];
        _SETTING_PASSWORD = [self getCharacteristic:MYLE_CHAR_SETTING_PASSWORD forService:service];
        
        _COMMAND_AUDIO_FILE_DISPOSITION = [self getCharacteristic:MYLE_CHAR_COMMAND_AUDIO_FILE_DISPOSITION forService:service];
        _COMMAND_AUDIO_FILE_RECEIVED = [self getCharacteristic:MYLE_CHAR_COMMAND_AUDIO_FILE_RECEIVED forService:service];
        _COMMAND_BLUETOOTH_LOCATOR = [self getCharacteristic:MYLE_CHAR_COMMAND_BLUETOOTH_LOCATOR forService:service];
        _COMMAND_FACTORY_RESET = [self getCharacteristic:MYLE_CHAR_COMMAND_FACTORY_RESET forService:service];
        _COMMAND_PASSWORD = [self getCharacteristic:MYLE_CHAR_COMMAND_PASSWORD forService:service];
        _COMMAND_UPDATE_TIME = [self getCharacteristic:MYLE_CHAR_COMMAND_UPDATE_TIME forService:service];
        
        _STATUS_AUDIO_FILE_PACKET = [self getCharacteristic:MYLE_CHAR_STATUS_AUDIO_FILE_PACKET forService:service];
        _STATUS_AUDIO_FILE_SENT = [self getCharacteristic:MYLE_CHAR_STATUS_AUDIO_FILE_SENT forService:service];
        _STATUS_AUDIO_FILE_STORED = [self getCharacteristic:MYLE_CHAR_STATUS_AUDIO_FILE_STORED forService:service];
        _STATUS_PASSWORD_VALIDITY = [self getCharacteristic:MYLE_CHAR_STATUS_PASSWORD_VALIDITY forService:service];
        
        if (_STATUS_AUDIO_FILE_PACKET) {
            [service.peripheral setNotifyValue:YES forCharacteristic:_STATUS_AUDIO_FILE_PACKET];
        }
        if (_STATUS_AUDIO_FILE_SENT) {
            [service.peripheral setNotifyValue:YES forCharacteristic:_STATUS_AUDIO_FILE_SENT];
        }
        if (_STATUS_AUDIO_FILE_STORED) {
            [service.peripheral setNotifyValue:YES forCharacteristic:_STATUS_AUDIO_FILE_STORED];
        }
        if (_STATUS_PASSWORD_VALIDITY) {
            [service.peripheral setNotifyValue:YES forCharacteristic:_STATUS_PASSWORD_VALIDITY];
        }
    } else if ([[service UUID] isEqual:[CBUUID UUIDWithString:DEVINFO_SERVICE_UUID]]) {
        _devInfoHardwareRevChrt = [self getCharacteristic:DEVINFO_HARDWARE_REV_UUID forService:service];
        _devInfoFirmwareRevChrt = [self getCharacteristic:DEVINFO_FIRMWARE_REV_UUID forService:service];
    }
}


// List characteristics
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    if (error) {
        [self trace:@"Error discovering characteristics for service %@: %@", service.UUID.UUIDString, error];
        [self cleanup];
        return;
    }
    [self trace:@"Discovered characteristics for service %@: %@", service, service.characteristics];
    
    [self initCharacterisitcsForService:service];
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
    
    [self trace:@"[>] Received in charc %@:\r\n%@", (characteristic.UUID.UUIDString.length >= 8) ? [characteristic.UUID.UUIDString substringToIndex:8] : characteristic.UUID.UUIDString, characteristic.value];
    
    Byte *bytes = (Byte*)(characteristic.value.bytes);

    if (characteristic == _STATUS_PASSWORD_VALIDITY)
    {
        // if we are in the middle of authentication, and received password status flag set to 1, then we are authenticated
        if (_isAuthenticating) {
            if (((Byte*)characteristic.value.bytes)[0] & 0x01) {
                [self trace:@"Password is OK!"];
                
                _isAuthenticating = NO;
                _isConnected = YES;
                
                // notify subscribers about connected peripheral
                [self trace:@"Broadcasting about connected tap"];
                [[NSNotificationCenter defaultCenter] postNotificationName:kTapNtfn
                                                                    object:nil
                                                                  userInfo:@{ kTapNtfnType: @kTapNtfnTypeConnected }];
                
                [self trace:@"Sending current time"];
                [self sendCurrentTime];
                
                // check maybe there are files stored in TAP
                //[_currentPeripheral readValueForCharacteristic:_STATUS_AUDIO_FILE_STORED];
            }
        }
    }
    else if (characteristic == _STATUS_AUDIO_FILE_STORED)
    {
        AudioFileStored *metadata = (AudioFileStored*)characteristic.value.bytes;
        
        [self trace:@"Received Audio File Strored value:\r\n\tMetadata version: %@\r\n\tFile exists: %@\r\n\tTime and date valid: %@\r\n\tCodec ID: %@\r\n\tSecond: %@\r\n\tMinute: %@\r\n\tHour: %@\r\n\tDay: %@\r\n\tMonth: %@\r\n\tYear: %@\r\n\tFile size: %@\r\n\tPacket size: %@\r\n\tFile index: %@", metadata->version, metadata->fileExists, metadata->timeValid, metadata->codeId, metadata->second, metadata->minute, metadata->hour, metadata->day, metadata->month, metadata->year, metadata->fileSize, metadata->packetSize, metadata->fileIndex];
        
        if (metadata->fileExists) {
            [self trace:@"File exists on TAP, sending command to initiate file transfer"];
            
            AudioFileDisposition cmd;
            cmd.fileIndex = metadata->fileIndex;
            cmd.command = 0; // transfer file
            
            //_currentFileIndex = metadata->fileIndex;
            
            [_currentPeripheral writeValue:[NSData dataWithBytes:&cmd length:sizeof(AudioFileDisposition)] forCharacteristic:_COMMAND_AUDIO_FILE_DISPOSITION type:CBCharacteristicWriteWithResponse];
        }
    }
    else if (characteristic == _STATUS_AUDIO_FILE_SENT)
    {
        UInt32 *fileIndex = (UInt32*)characteristic.value.bytes;
        [self trace:@"Received audio with File Index %@! Sending back Audio File Received command...", *fileIndex];
        
        [_currentPeripheral writeValue:[NSData dataWithBytes:&fileIndex length:sizeof(UInt32)] forCharacteristic:_COMMAND_AUDIO_FILE_RECEIVED type:CBCharacteristicWriteWithResponse];
    }
    else  if (characteristic == _batteryLevelChrt)
    {
        [self trace:@"Battery level received: %d", bytes[0]];
        [self notifyReadParameterListeners:@"BATTERY_LEVEL" intValue:bytes[0] strValue:nil];
    }
    else if (characteristic == _SETTING_AUDIO_LENGTH)
    {
        [self notifyReadParameterListeners:@"RECLN" intValue:bytes[0] strValue:nil];
    }
    else if (characteristic == _SETTING_MIC_LEVEL)
    {
        [self notifyReadParameterListeners:@"MIC" intValue:bytes[0] strValue:nil];
    }
    else if (characteristic == _SETTING_SILENCE_LEVEL)
    {
        [self notifyReadParameterListeners:@"PAUSELEVEL" intValue:bytes[0] strValue:nil];
    }
    else if (characteristic == _SETTING_SILENCE_LENGTH)
    {
        [self notifyReadParameterListeners:@"PAUSELEN" intValue:bytes[0] strValue:nil];
    }
    else if (characteristic == _SETTING_ACCELEROMETER_SENSITIVITY)
    {
        [self notifyReadParameterListeners:@"ACCELERSENS" intValue:bytes[0] strValue:nil];
    }
    else if (characteristic == _SETTING_PASSWORD)
    {
        [self notifyReadParameterListeners:@"PASSWORD" intValue:0 strValue:[[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding]];
    }
    else if (characteristic == _devInfoFirmwareRevChrt)
    {
        [self notifyReadParameterListeners:@"FWVERSION" intValue:0 strValue:[[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding]];
    }
    else if (characteristic == _devInfoHardwareRevChrt)
    {
        [self notifyReadParameterListeners:@"HWVERSION" intValue:0 strValue:[[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding]];
    }
    


    
//    if (error) {
//        return [self trace:@"Error updating value for characteristic %@: %@", characteristic.UUID.UUIDString, error];
//    } else {
//        [self trace:@"[>] Received in charc %@:\r\n%@", (characteristic.UUID.UUIDString.length >= 8) ? [characteristic.UUID.UUIDString substringToIndex:8] :characteristic.UUID.UUIDString, characteristic.value];
//    }
//    
//    // Readback of the battery level
//    if (characteristic == _batteryLevelChrt) {
//        [self readBatteryLevel:characteristic.value];
//    }
//    
//    // Not correct characteristics
//    if (characteristic != _myleReadChrt) {
//        return;
//    }
//    
//    /*********** RECEIVE PARAMETER VALUE ***************/
//    if (!_isReceivingAudioFile && !_isReceivingLogFile) {
//        if([self readParameter:characteristic.value]) { return; }
//    }
//    
//    /*********** RECEIVE AUDIO FILE OR LOG FILE ********************/
//    
//    if (_receiveMode == RECEIVE_AUDIO_FILE) {
//        [self handleRecieveAudioFile: characteristic.value
//                      withPeripheral: peripheral
//                    withChararistics: characteristic];
//        
//    } else if (_receiveMode == RECEIVE_LOG_FILE) {
//        // Send back to peripheral number of bytes received.
//        [self handleRecieveLogFile: characteristic.value
//                    withPeripheral: peripheral
//                  withChararistics: characteristic];
//    }
}




// Update notification from peripheral
- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error) {
        return [self trace:@"Error updating notification state for characteristic %@: %@", characteristic.UUID.UUIDString, error];
    }
    
    [self trace:@"Changed notification state to %@ on characteristic %@", characteristic.isNotifying ? @"NOTIFYING" : @"NOT NOTIFYING", characteristic.UUID.UUIDString];
    
    if (characteristic == _STATUS_PASSWORD_VALIDITY && characteristic.isNotifying) {
        // Send password to board
        _isAuthenticating = YES;
    
        [self trace:@"Sending password: %@", _currentPass];
        [self sendPassword:_currentPass];
    }
}


#pragma mark - Utilities


//
//// Convert Integer to NSData
//-(NSData *) IntToNSData:(NSInteger)data
//{
//    Byte byteData[1] = { data & 0xff };
//    return [NSData dataWithBytes:byteData length:1];
//}
//
//- (NSUInteger) getFromBytes:(Byte *) byteData {
//    int dv = byteData[2]-48;
//    int ch = byteData[1]-48;
//    int ngh = byteData[0]-48;
//    
//    NSUInteger value = dv + ch*10 + ngh*100;
//    
//    return value;
//}
//

- (void)handleRecieveAudioFile: (NSData*)data
                withPeripheral: (CBPeripheral*)peripheral
              withChararistics: (CBCharacteristic*)characteristic {
    
//    static CFTimeInterval startTime = 0;
//    
//    if (_audioLength == 0) // First packet
//    {
//        unsigned int ml;
//        
//        [characteristic.value getBytes:&ml length:4];
//        [self trace:[NSString stringWithFormat:@"Read record metadata: metadata length = %d", ml]];
//        
//        [characteristic.value getBytes:&_audioLength range:NSMakeRange(4, 4)];
//        [self trace:[NSString stringWithFormat:@"Read record metadata: audio length = %d", _audioLength]];
//        
//        [characteristic.value getBytes:&_audioRecordedTime range:NSMakeRange(8, 4)];
//        
//        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
//        [formatter setDateFormat:TimeFormat];
//        [self trace:[NSString stringWithFormat:@"Read record metadata: record time = %@", [formatter stringFromDate:[self getDateFromInt:_audioRecordedTime]]]];
//        
//        [self trace:@"Receiving audio data..."];
//        
//        _audioBuffer = [[NSMutableData alloc] init];
//        _isReceivingAudioFile = true;
//        _progress = 0;
//        
//        NSInteger numBytes = CREDITBLE;
//        Byte byteData[2] = { numBytes & 0xff, numBytes >> 8 };
//        NSData *data2 = [NSData dataWithBytes:byteData length:2];
//        
//        [self writeValue:data2 forCharc:_myleWriteChrt];
//        
//        startTime = CACurrentMediaTime();
//        
//    }
//    else if (_audioBuffer.length < _audioLength)
//    {
//        static NSInteger numBytesTransfered = 0;
//        
//        [_audioBuffer appendData:characteristic.value];
//        
//        float currentProgress = (float)_audioBuffer.length / (float)_audioLength;
//        if (fabsf(currentProgress - _progress) >= PROGRESS_LOG_DELTA || _audioBuffer.length == _audioLength) {
//            _progress = currentProgress;
//            [self trace:@"Received %d%%", (int)(_progress * 100.0f)];
//        }
//        
//        if (_audioBuffer.length >= _audioLength)
//        {
//            CFTimeInterval elapsedTime = CACurrentMediaTime() - startTime;
//            
//            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
//            [formatter setDateFormat:RecordFileFormat];
//            NSString *fileName = [NSString stringWithFormat:@"%@.wav", [formatter stringFromDate:[self getDateFromInt:_audioRecordedTime]]];
//            NSString *filePath = [DocumentsPath() stringByAppendingPathComponent:fileName];
//            
//            [_audioBuffer writeToFile:filePath atomically:YES];
//            
//            [self trace:[NSString stringWithFormat:@"Audio saved to %@", fileName]];
//            [self trace:[NSString stringWithFormat:@"Transfer speed %d B/s", (int)(_audioLength/elapsedTime)]];
//            
//            // reset
//            _audioLength = 0;
//            _progress = 0;
//            _isReceivingAudioFile = false;
//            _receiveMode = RECEIVE_NONE;
//            
//            // notify subscribers about new file appearence
//            [self trace:@"Broadcasting about received file"];
//            [[NSNotificationCenter defaultCenter] postNotificationName:kTapNtfn
//                                                                object:nil
//                                                              userInfo:@{ kTapNtfnType: @kTapNtfnTypeFile, kTapNtfnFilePath: filePath, kTapNtfnMAC: _currentMAC }];
//        }
//        else{
//            
//            numBytesTransfered += characteristic.value.length;
//            
//            NSInteger numBytes = CREDITBLE;
//            if(_audioLength - _audioBuffer.length < CREDITBLE)
//            {
//                numBytes = _audioLength - _audioBuffer.length;
//            }
//            
//            if(numBytesTransfered >= numBytes)
//            {
//                numBytesTransfered = 0;
//                Byte byteData[2] = { numBytes & 0xff, numBytes >> 8 };
//                NSData *data2 = [NSData dataWithBytes:byteData length:2];
//                [self writeValue:data2 forCharc:_myleWriteChrt];
//            }
//        }
//    }
}


- (void)handleRecieveLogFile: (NSData*)data
              withPeripheral: (CBPeripheral*)peripheral
            withChararistics: (CBCharacteristic*)characteristic {
    
//    static NSInteger numBytesTransfered = 0;
//    static unsigned int fileLength = 0;
//    
//    // perform some action
//    if (_logLength == 0) // First packet
//    {
//        unsigned int ml;
//        
//        [data getBytes:&ml length:4];
//        [self trace:[NSString stringWithFormat:@"Log metadata: metadata length = %d", ml]];
//        
//        [data getBytes:&_logLength range:NSMakeRange(4, 4)];
//        [self trace:[NSString stringWithFormat:@"Log metadata: log length = %d", _logLength]];
//        
//        [data getBytes:&_logCreatedTime range:NSMakeRange(8, 4)];
//        
//        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
//        [formatter setDateFormat:TimeFormat];
//        [self trace:[NSString stringWithFormat:@"Log metadata: created time = %@", [formatter stringFromDate:[self getDateFromInt:_logCreatedTime]]]];
//        
//        [self trace:@"Receiving log data ..."];
//        
//        _logBuffer = [[NSMutableData alloc] init];
//        _isReceivingLogFile = true;
//        NSInteger numBytes = 235;
//        NSData *data = [self IntToNSData:numBytes];
//        [self writeValue:data forCharc:_myleWriteChrt];
//    }
//    else if (_logBuffer.length < _logLength)
//    {
//        [_logBuffer appendData:data];
//        
//        if (_logBuffer.length >= _logLength)
//        {
//            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
//            [formatter setDateFormat:RecordFileFormat];
//            NSString *fileName = [NSString stringWithFormat:@"%@.log", [formatter stringFromDate:[self getDateFromInt:_logCreatedTime]]];
//            
//            NSString *filePath = [DocumentsPath() stringByAppendingPathComponent:fileName];
//            [_logBuffer writeToFile:filePath atomically:YES];
//            
//            [self trace:[NSString stringWithFormat:@"Log saved to %@", fileName]];
//            
//            // Reset
//            _logLength = 0;
//            _isReceivingLogFile = false;
//            _receiveMode = RECEIVE_NONE;
//        }
//        else{
//            
//            numBytesTransfered += characteristic.value.length;
//            fileLength += numBytesTransfered;
//            
//            NSInteger numBytes = 235;
//            if(_logLength - _logBuffer.length < 235)
//            {
//                numBytes = _logLength - _logBuffer.length;
//            }
//            
//            if(numBytesTransfered >= numBytes)
//            {
//                numBytesTransfered = 0;
//                NSData *data = [self IntToNSData:numBytes];
//                [self writeValue:data forCharc:_myleWriteChrt];
//            }
//        }
//    }
}


- (void) writeValue:(NSData *)value forCharc:(CBCharacteristic*)charc
{
    [self trace:@"[<] Sent to charc %@:\r\n%@", (charc.UUID.UUIDString.length >= 8) ? [charc.UUID.UUIDString substringToIndex:8] : charc.UUID.UUIDString, value];
    [_currentPeripheral writeValue:value forCharacteristic:charc type:CBCharacteristicWriteWithResponse];
}


- (void) sendParameter: (NSData *) data
{
    //[self writeValue:data forCharc:_myleWriteChrt];
}


- (void)sendPassword:(NSString*)password {
    NSData *passwordData = [password dataUsingEncoding:NSUTF8StringEncoding];
    passwordData = (passwordData.length > 11)
        ? [passwordData subdataWithRange:NSMakeRange(0, 11)]
        : passwordData;
    
    NSMutableData *paddedData = [NSMutableData dataWithData:passwordData];
    [paddedData increaseLengthBy:12 - passwordData.length];
    
    [self trace:@"Sending password for authentication: %@", paddedData];
    [_currentPeripheral writeValue:paddedData forCharacteristic:_COMMAND_PASSWORD type:CBCharacteristicWriteWithResponse];
}


- (void) sendCurrentTime {
    // Sync time to board
    NSCalendar *calendar = [NSCalendar currentCalendar];
    calendar.timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
    NSDateComponents *components = [calendar components:(NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond | NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear) fromDate:[NSDate date]];
    
    NSInteger hour = [components hour];
    NSInteger minute = [components minute];
    NSInteger second = [components second];
    NSInteger day = [components day];
    NSInteger month = [components month];
    NSInteger year = [components year];
    
    Byte byteData[6] = { second & 0xff, minute & 0xff, hour & 0xff, day & 0xff, month & 0xff, (year - 2000) & 0xff };
    NSData *data = [NSData dataWithBytes:byteData length:6];
    
    [self trace:@"Sending current time: %@", data];
    [_currentPeripheral writeValue:data forCharacteristic:_COMMAND_UPDATE_TIME type:CBCharacteristicWriteWithResponse];
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
- (void)sendWriteRECLN: (Byte)value {
    Byte bytes[1] = { value };
    [_currentPeripheral writeValue:[NSData dataWithBytes:bytes length:1] forCharacteristic:_SETTING_AUDIO_LENGTH type:CBCharacteristicWriteWithResponse];
}

// Update parameter MIC
- (void)sendWriteMIC:(Byte)value {
    Byte bytes[1] = { value };
    [_currentPeripheral writeValue:[NSData dataWithBytes:bytes length:1] forCharacteristic:_SETTING_MIC_LEVEL type:CBCharacteristicWriteWithResponse];
}

// Update Parameter PAUSE_LEVEL
- (void)sendWritePAUSELEVEL: (Byte)value {
    Byte bytes[1] = { value };
    [_currentPeripheral writeValue:[NSData dataWithBytes:bytes length:1] forCharacteristic:_SETTING_SILENCE_LEVEL type:CBCharacteristicWriteWithResponse];
}

// Update Parameter PAUSE_LEN
- (void)sendWritePAUSELEN: (Byte)value{
    Byte bytes[1] = { value };
    [_currentPeripheral writeValue:[NSData dataWithBytes:bytes length:1] forCharacteristic:_SETTING_SILENCE_LENGTH type:CBCharacteristicWriteWithResponse];
}

// Update Parameter ACCELER_SENS
- (void)sendWriteACCELERSENS:(Byte)value {
    Byte bytes[1] = { value };
    [_currentPeripheral writeValue:[NSData dataWithBytes:bytes length:1] forCharacteristic:_SETTING_ACCELEROMETER_SENSITIVITY type:CBCharacteristicWriteWithResponse];
}

- (void)sendWritePASSWORD:(NSString *)value {
    NSData *passwordData = [value dataUsingEncoding:NSUTF8StringEncoding];
    passwordData = (passwordData.length > 11)
    ? [passwordData subdataWithRange:NSMakeRange(0, 11)]
    : passwordData;
    
    NSMutableData *paddedData = [NSMutableData dataWithData:passwordData];
    [paddedData increaseLengthBy:12 - passwordData.length];
    [_currentPeripheral writeValue:paddedData forCharacteristic:_SETTING_PASSWORD type:CBCharacteristicWriteWithResponse];
}
/************ END UPDATE PARAMETER ****************/

/************ READ PARAMETER ****************/

- (void)sendReadRECLN {
    [_currentPeripheral readValueForCharacteristic:_SETTING_AUDIO_LENGTH];
}

- (void)sendReadMIC {
    [_currentPeripheral readValueForCharacteristic:_SETTING_MIC_LEVEL];
}

- (void)sendReadPAUSELEVEL {
    [_currentPeripheral readValueForCharacteristic:_SETTING_SILENCE_LEVEL];
}

- (void)sendReadPAUSELEN {
    [_currentPeripheral readValueForCharacteristic:_SETTING_SILENCE_LENGTH];
}

- (void)sendReadACCELERSENS {
    [_currentPeripheral readValueForCharacteristic:_SETTING_ACCELEROMETER_SENSITIVITY];
}

- (void)sendReadPASSWORD {
    [_currentPeripheral readValueForCharacteristic:_SETTING_PASSWORD];
}

- (void)sendReadBATTERY_LEVEL {
    [_currentPeripheral readValueForCharacteristic:_batteryLevelChrt];
}

- (void)sendReadFirmwareVersion {
    [_currentPeripheral readValueForCharacteristic:_devInfoFirmwareRevChrt];
}

- (void)sendReadHardwareVersion {
    [_currentPeripheral readValueForCharacteristic:_devInfoHardwareRevChrt];
}

/************ END READ PARAMETER ****************/


- (NSString*) getCurrentTapUUID
{
    return _currentUUID;
}


- (NSString*) getCurrentTapPassword {
    return _currentPass;
}


- (NSString*) getCurrentTapMAC
{
    return _currentMAC;
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
    NSMutableString *format = [formatString mutableCopy];
    [format appendString:@"\r\n"];
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
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