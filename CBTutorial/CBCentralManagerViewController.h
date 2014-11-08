//
//  ViewController.h
//  IOS_BLE
//
//  Created by cxphong-macmini on 11/5/14.
//  Copyright (c) 2014 cxphong. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreBluetooth/CoreBluetooth.h>

#import "SERVICES.h"

@interface CBCentralManagerViewController : UIViewController < CBCentralManagerDelegate, CBPeripheralDelegate>
//@property (weak, nonatomic) IBOutlet UITextField *tfSend;
@property (weak, nonatomic) IBOutlet UITextView *tvLog;
//@property (weak, nonatomic) IBOutlet UIButton *btSend;
@property (nonatomic,strong) NSFileHandle *handle;
@property NSString *PeripheralUUID;
@property unsigned int dataLength;

@property (strong, nonatomic) CBCentralManager *centralManager;
@property (strong, nonatomic) CBPeripheral *discoveredPeripheral;
@property (strong, nonatomic) CBPeripheralManager *peripheralManager;
@property (strong, nonatomic) NSMutableData *data;

- (void)centralManagerDidUpdateState:(CBCentralManager *)central;

@end
