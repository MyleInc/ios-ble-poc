//
//  CBCentralManagerViewController.h
//  CBTutorial
//
//  Created by Orlando Pereira on 10/8/13.
//  Copyright (c) 2013 Mobiletuts. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreBluetooth/CoreBluetooth.h>

#import "SERVICES.h"

@interface CBCentralManagerViewController : UIViewController < CBCentralManagerDelegate, CBPeripheralDelegate>


//@property (weak, nonatomic) IBOutlet UIButton *btConnect;
@property (weak, nonatomic) IBOutlet UILabel *lbViewer;
//@property (weak, nonatomic) IBOutlet UITextField *tfSend;
@property (weak, nonatomic) IBOutlet UITextView *tvLog;
//@property (weak, nonatomic) IBOutlet UIButton *btSend;
@property (nonatomic,strong) NSFileHandle *handle;
@property NSString *PeripheralUUID;

- (IBAction)TextfileDone:(id)sender;

- (IBAction)SendData:(id)sender;
@property (strong, nonatomic) CBCentralManager *centralManager;
@property (strong, nonatomic) CBPeripheral *discoveredPeripheral;
@property (strong, nonatomic) CBPeripheralManager *peripheralManager;
@property (strong, nonatomic) NSMutableData *data;

- (IBAction)ConnectPeripheral:(id)sender;

- (void)centralManagerDidUpdateState:(CBCentralManager *)central;

-(NSData *) IntToNSData:(NSInteger)data;

@end
