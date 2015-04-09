//
//  ViewController.h
//  IOS_BLE
//
//  Created by cxphong-macmini on 11/5/14.
//  Copyright (c) 2014 cxphong. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreBluetooth/CoreBluetooth.h>

@interface CBCentralManagerViewController : UIViewController

@property (weak, nonatomic) IBOutlet UITextView *tvLog;

@end
