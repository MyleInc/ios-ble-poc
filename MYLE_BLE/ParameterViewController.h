//
//  ParameterViewController.h
//  MYLE_BLE
//
//  Created by cxphong-macmini on 12/25/14.
//  Copyright (c) 2014 Mobiletuts. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CBCentralManagerViewController.h"

@interface ParameterViewController : UIViewController <ParameterDelegate, UITextFieldDelegate>

- (IBAction)tfExit:(id)sender;
- (void) setPeripheral: (CBCentralManagerViewController *)viewcontroller peripheral: (CBPeripheral *)_peripheral;

// RECLN
@property (weak, nonatomic) IBOutlet UITextField *tfRECLN;


// PAUSE_LEVEL
@property (weak, nonatomic) IBOutlet UITextField *tfPAUSE_LEVEL;


// PAUSE_LEN
@property (weak, nonatomic) IBOutlet UITextField *tfPAUSE_LEN;

// ACCELER_SENS
@property (weak, nonatomic) IBOutlet UITextField *tfACCELER_SENS;

// MIC
@property (weak, nonatomic) IBOutlet UITextField *tfMIC;


// PASSWORD
@property (weak, nonatomic) IBOutlet UITextField *tfPASSWORD;


// BTLOC
@property (weak, nonatomic) IBOutlet UITextField *tfBTLOC;

// UUID
@property (weak, nonatomic) IBOutlet UITextView *tvUUID;


// VERSION
@property (weak, nonatomic) IBOutlet UITextField *tfVERSION;

@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;

@property (weak, nonatomic) IBOutlet UIButton *btReadAll;
- (IBAction)readAll:(id)sender;

@property (weak, nonatomic) IBOutlet UIButton *btWriteAll;
- (IBAction)writeAll:(id)sender;




@end
