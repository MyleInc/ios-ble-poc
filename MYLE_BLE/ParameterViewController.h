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
@property (weak, nonatomic) IBOutlet UIButton *btReadRECLN;
@property (weak, nonatomic) IBOutlet UIButton *btWriteRECLN;
- (IBAction)readRECLN:(id)sender;
- (IBAction)writeRECLN:(id)sender;

// PAUSE_LEVEL
@property (weak, nonatomic) IBOutlet UITextField *tfPAUSE_LEVEL;
@property (weak, nonatomic) IBOutlet UIButton *btReadPAUSE_LEVEL;
@property (weak, nonatomic) IBOutlet UIButton *btWritePAUSE_LEVEL;
- (IBAction)readPAUSE_LEVEL:(id)sender;
- (IBAction)writePAUSE_LEVEL:(id)sender;

// PAUSE_LEN
@property (weak, nonatomic) IBOutlet UITextField *tfPAUSE_LEN;
@property (weak, nonatomic) IBOutlet UIButton *btReadPAUSE_LEN;
@property (weak, nonatomic) IBOutlet UIButton *btWritePAUSE_LEN;
- (IBAction)readPAUSE_LEN:(id)sender;
- (IBAction)writePAUSE_LEN:(id)sender;

// ACCELER_SENS
@property (weak, nonatomic) IBOutlet UITextField *tfACCELER_SENS;
@property (weak, nonatomic) IBOutlet UIButton *btReadACCELER_SENS;
@property (weak, nonatomic) IBOutlet UIButton *btWriteACCELER_SENS;
- (IBAction)readACCELER_SENS:(id)sender;
- (IBAction)writeACCELER_SENS:(id)sender;

// MIC
@property (weak, nonatomic) IBOutlet UITextField *tfMIC;
@property (weak, nonatomic) IBOutlet UIButton *btReadMIC;
@property (weak, nonatomic) IBOutlet UIButton *btWriteMIC;
- (IBAction)readMIC:(id)sender;
- (IBAction)writeMIC:(id)sender;

// PASSWORD
@property (weak, nonatomic) IBOutlet UITextField *tfPASSWORD;
@property (weak, nonatomic) IBOutlet UIButton *btReadPASSWORD;
@property (weak, nonatomic) IBOutlet UIButton *btWritePASSWORD;
- (IBAction)readPASSWORD:(id)sender;
- (IBAction)writePASSWORD:(id)sender;

// BTLOC
@property (weak, nonatomic) IBOutlet UITextField *tfBTLOC;
@property (weak, nonatomic) IBOutlet UIButton *btReadBTLOC;
@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;
- (IBAction)readBTLOC:(id)sender;
@end
